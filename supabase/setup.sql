-- Base vectorial para el agente de pedidos (Supabase + pgvector)
-- Dimensión 768 = salida del modelo de embeddings nomic-embed-text (Ollama)

create extension if not exists vector;

create table documents (
  id bigserial primary key,
  content text,
  metadata jsonb,
  embedding vector(768)
);

-- Row Level Security: bloquea el acceso con claves públicas (anon / authenticated)
alter table documents enable row level security;

create function match_documents (
  query_embedding vector(768),
  match_count int default null,
  filter jsonb default '{}'
) returns table (id bigint, content text, metadata jsonb, similarity float)
language plpgsql as $$
#variable_conflict use_column
begin
  return query
  select id, content, metadata, 1 - (documents.embedding <=> query_embedding) as similarity
  from documents
  where metadata @> filter
  order by documents.embedding <=> query_embedding
  limit match_count;
end;
$$;

-- Permisos para la clave de servicio que usa n8n
grant usage on schema public to service_role;
grant all on table public.documents to service_role;
grant usage, select on sequence public.documents_id_seq to service_role;

-- La función de búsqueda (solo lectura) corre con permisos del dueño,
-- así devuelve resultados aunque la tabla tenga RLS activado
alter function match_documents(vector, int, jsonb) security definer set search_path = public, extensions;
grant execute on function match_documents(vector, int, jsonb) to anon, authenticated, service_role;

-- Verificación: debe dar catalogo = 146 y reglas = 13
-- select metadata->>'tipo' as tipo, count(*) from documents group by 1;
