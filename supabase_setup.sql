-- ============================================================
-- SUPABASE SETUP — Sistema de Agendamento com Google Calendar
-- Execute este SQL no SQL Editor do seu projeto Supabase
-- ============================================================

-- 1. TABELA PRINCIPAL DE EVENTOS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.calendar_events (
  id            uuid            DEFAULT gen_random_uuid() PRIMARY KEY,
  event_id      text            UNIQUE NOT NULL,        -- ID retornado pelo Google Calendar
  calendar_id   text            DEFAULT 'primary',      -- ID do calendário ('primary' ou custom)
  summary       text,                                   -- Título do evento
  description   text,                                   -- Descrição
  start_time    timestamptz,                            -- Início com timezone
  end_time      timestamptz,                            -- Fim com timezone
  attendees     text,                                   -- Emails separados por vírgula
  status        text            DEFAULT 'confirmed',    -- confirmed | tentative | cancelled
  html_link     text,                                   -- Link direto para o evento no Google
  created_at    timestamptz     DEFAULT now(),          -- Criado em
  updated_at    timestamptz     DEFAULT now(),          -- Atualizado em
  deleted_at    timestamptz     DEFAULT NULL            -- Soft delete (NULL = ativo)
);

-- 2. ÍNDICES PARA PERFORMANCE
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_calendar_events_event_id
  ON public.calendar_events (event_id);

CREATE INDEX IF NOT EXISTS idx_calendar_events_start_time
  ON public.calendar_events (start_time);

CREATE INDEX IF NOT EXISTS idx_calendar_events_status
  ON public.calendar_events (status);

-- 3. TRIGGER PARA ATUALIZAR updated_at AUTOMATICAMENTE
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER trigger_calendar_events_updated_at
  BEFORE UPDATE ON public.calendar_events
  FOR EACH ROW
  EXECUTE PROCEDURE update_updated_at_column();

-- 4. VIEW: APENAS EVENTOS ATIVOS (não deletados)
-- ============================================================
CREATE OR REPLACE VIEW public.calendar_events_active AS
  SELECT * FROM public.calendar_events
  WHERE deleted_at IS NULL
  ORDER BY start_time ASC;

-- 5. VIEW: PRÓXIMOS EVENTOS (futuros e ativos)
-- ============================================================
CREATE OR REPLACE VIEW public.calendar_events_upcoming AS
  SELECT * FROM public.calendar_events
  WHERE deleted_at IS NULL
    AND start_time >= now()
  ORDER BY start_time ASC;

-- 6. RLS (Row Level Security) — OPCIONAL mas recomendado
-- ============================================================
-- Habilite apenas se quiser segurança por usuário
-- ALTER TABLE public.calendar_events ENABLE ROW LEVEL SECURITY;

-- Policy para service role (n8n usa service role — sempre tem acesso total)
-- CREATE POLICY "Service role full access"
--   ON public.calendar_events
--   FOR ALL
--   USING (true)
--   WITH CHECK (true);

-- ============================================================
-- DADOS DE EXEMPLO PARA TESTE
-- ============================================================
-- INSERT INTO public.calendar_events (event_id, summary, start_time, end_time, status)
-- VALUES ('test_event_001', 'Reunião de Teste', now() + interval '1 day', now() + interval '1 day' + interval '1 hour', 'confirmed');

-- ============================================================
-- VERIFICAR ESTRUTURA
-- ============================================================
-- SELECT column_name, data_type, is_nullable, column_default
-- FROM information_schema.columns
-- WHERE table_schema = 'public'
--   AND table_name = 'calendar_events'
-- ORDER BY ordinal_position;
