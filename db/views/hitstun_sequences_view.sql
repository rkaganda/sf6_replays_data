-- public.hitstun_sequences_view source

CREATE OR REPLACE VIEW public.hitstun_sequences_view
AS WITH raw_data AS (
         SELECT cfn_raw_replays.cfn_replay_id,
            cfn_raw_replays.round_number,
            cfn_raw_replays.frame,
            0 AS player_id,
            cfn_raw_replays.p0_act_st AS act_st
           FROM cfn_raw_replays
        UNION ALL
         SELECT cfn_raw_replays.cfn_replay_id,
            cfn_raw_replays.round_number,
            cfn_raw_replays.frame,
            1 AS player_id,
            cfn_raw_replays.p1_act_st AS act_st
           FROM cfn_raw_replays
        ), act_st_sequences AS (
         SELECT raw_data.cfn_replay_id,
            raw_data.round_number,
            raw_data.frame,
            raw_data.player_id,
            raw_data.act_st,
                CASE
                    WHEN (raw_data.act_st = ANY (ARRAY[32, 35, 38])) AND (lag(raw_data.act_st, 1, '-1'::integer) OVER (PARTITION BY raw_data.cfn_replay_id, raw_data.round_number, raw_data.player_id ORDER BY raw_data.frame) <> ALL (ARRAY[32, 35, 38])) THEN 1
                    ELSE 0
                END AS is_new_sequence
           FROM raw_data
        ), sequence_identification AS (
         SELECT act_st_sequences.cfn_replay_id,
            act_st_sequences.round_number,
            act_st_sequences.frame,
            act_st_sequences.player_id,
            act_st_sequences.act_st,
            act_st_sequences.is_new_sequence,
            sum(act_st_sequences.is_new_sequence) OVER (PARTITION BY act_st_sequences.cfn_replay_id, act_st_sequences.round_number, act_st_sequences.player_id ORDER BY act_st_sequences.frame) AS sequence_id
           FROM act_st_sequences
          WHERE act_st_sequences.act_st = ANY (ARRAY[32, 35, 38])
        ), sequence_bounds AS (
         SELECT sequence_identification.cfn_replay_id,
            sequence_identification.round_number,
            sequence_identification.player_id,
            sequence_identification.sequence_id,
            min(sequence_identification.frame) AS start_frame,
            max(sequence_identification.frame) AS end_frame
           FROM sequence_identification
          GROUP BY sequence_identification.cfn_replay_id, sequence_identification.round_number, sequence_identification.player_id, sequence_identification.sequence_id
        )
 SELECT sb.cfn_replay_id,
    sb.round_number,
    sb.player_id,
    sb.sequence_id,
    sb.start_frame,
    sb.end_frame
   FROM sequence_bounds sb
  ORDER BY sb.cfn_replay_id, sb.round_number, sb.player_id, sb.sequence_id;

-- Permissions

ALTER TABLE public.hitstun_sequences_view OWNER TO sf6_data;
GRANT ALL ON TABLE public.hitstun_sequences_view TO sf6_data;
GRANT INSERT, SELECT, UPDATE ON TABLE public.hitstun_sequences_view TO sf6_upload WITH GRANT OPTION;