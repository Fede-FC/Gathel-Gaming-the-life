-- ==============================================================================
-- 01_cheatsheet.sql  |  Gathel — Referencia rápida
-- Mantener abierto todo el tiempo en una pestaña de SSMS.
-- NO ejecutar completo; seleccionar la sección que necesitas.
-- ==============================================================================

USE GathelDB;
GO

-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║  TABLAS Y COLUMNAS CLAVE                                                   ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

/*
Player
  player_id | username | email | display_name
  balance_points | balance_version | enabled | created_at

Proposition
  proposition_id | creator_player_id | target_player_id
  title | description | status_id | ai_review_result
  voting_ends_at | prediction_ends_at
  is_accepted_by_target | is_fulfilled | resolved_at | enabled | created_at

Prediction
  prediction_id | proposition_id | player_id
  amount | currency_type_id | direction (1=sí/0=no)
  result (PENDING|WON|LOST) | created_at

[Transaction]
  transaction_id | player_id | currency_type_id
  amount | running_balance | transaction_type_id
  reference_type | reference_id | description | created_at

GameEvent
  event_id | proposition_id | event_type_id
  actor_player_id | event_data (JSON) | created_at

Vote
  vote_id | proposition_id | player_id | created_at

AIReviewLog
  review_id | proposition_id | ai_model_id | ai_provider_id
  review_result (APPROVED|REJECTED|PENDING)
  confidence_score | reviewed_at

PropositionAudit
  audit_id | proposition_id | field_name | old_value | new_value
  changed_by | changed_at

PropositionEvidence
  evidence_id | proposition_id | evidence_url
  evidence_type (PHOTO|VIDEO|STORY|REEL|TWEET|POST)
  social_network_id | created_at

SocialAccount
  social_account_id | player_id | social_network_id
  account_username | is_verified | enabled

ExchangeRate
  exchange_rate_id | currency_type_id | rate_to_usd | effective_date
*/

-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║  CATÁLOGOS — IDs más usados                                                ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

-- Estados de proposición
-- 1 PENDING | 2 ACTIVE | 3 PREDICTION_CLOSED | 4 RESOLVED | 5 REJECTED | 6 CANCELLED

-- Monedas
-- 1 POINTS (virtual) | 2 USD | 3 EUR | 4 CRC  (verificar con SELECT * FROM CurrencyType)

-- Tipos de transacción
-- DEPOSIT | WITHDRAWAL | WAGER | WINNING | REFUND | COMMISSION | PURCHASE

-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║  STORED PROCEDURES — FIRMAS                                                ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

/*
usp_RegisterPlayer
    @username, @email, @password_hash, @display_name=NULL
    OUTPUT: @new_player_id

usp_CreateProposition
    @creator_player_id, @target_player_id
    @title, @description, @voting_ends_at
    OUTPUT: @new_proposition_id

usp_RecordAIReview
    @proposition_id, @ai_model_id, @ai_provider_id
    @review_result ('APPROVED'|'REJECTED')
    @confidence_score=NULL, @review_details=NULL

usp_AcceptProposition
    @proposition_id, @target_player_id, @prediction_ends_at

usp_RejectProposition
    @proposition_id, @target_player_id

usp_PlacePrediction
    @proposition_id, @player_id
    @amount, @currency_code ('POINTS'|'USD'|'EUR'|'CRC')
    @direction (1=se cumple / 0=no se cumple)
    OUTPUT: @new_prediction_id

usp_ClosePropositionPredictions
    @proposition_id

usp_ResolveProposition
    @proposition_id, @is_fulfilled (1|0|NULL), @resolved_by=NULL

usp_DepositMoney
    @player_id, @currency_code, @amount

usp_GetPlayerDashboard    @player_id
usp_GetActivePropositions @page_number=1, @page_size=20
usp_GetPropositionResults @player_id
*/

-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║  USUARIOS DE SEGURIDAD                                                     ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

/*
gathel_admin_usr    / GathelAdmin123!Secure    → rol db_gathel_admin
gathel_system_usr   / GathelSystem123!Secure   → rol db_gathel_system
gathel_player_usr   / GathelPlayer123!Secure   → rol db_gathel_player
gathel_readonly_usr / GathelReadOnly123!Secure → rol db_gathel_readonly
*/

-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║  SELECTS RÁPIDOS DE EMERGENCIA                                             ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

-- Ver cualquier tabla al vuelo:
SELECT TOP 10 * FROM Player           ORDER BY created_at DESC;
SELECT TOP 10 * FROM Proposition      ORDER BY created_at DESC;
SELECT TOP 10 * FROM Prediction       ORDER BY created_at DESC;
SELECT TOP 10 * FROM [Transaction]    ORDER BY created_at DESC;
SELECT TOP 10 * FROM GameEvent        ORDER BY created_at DESC;
SELECT TOP 10 * FROM AIReviewLog      ORDER BY reviewed_at DESC;
SELECT TOP 10 * FROM PropositionAudit ORDER BY changed_at  DESC;
