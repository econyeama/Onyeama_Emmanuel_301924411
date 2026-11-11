-- race_vars.sql — run FIRST in each psql terminal:   \i sql/race_vars.sql
-- Loads :sess, :ca, :cb, :cc, :seat, :seat2, :seat3, :fee from race_demo, so
-- every step in guides/race_condition_two_terminal.md can be pasted as written.
SELECT max(val) FILTER (WHERE key = 'sess')  AS sess,
       max(val) FILTER (WHERE key = 'ca')    AS ca,
       max(val) FILTER (WHERE key = 'cb')    AS cb,
       max(val) FILTER (WHERE key = 'cc')    AS cc,
       max(val) FILTER (WHERE key = 'seat')  AS seat,
       max(val) FILTER (WHERE key = 'seat2') AS seat2,
       max(val) FILTER (WHERE key = 'seat3') AS seat3,
       max(val) FILTER (WHERE key = 'fee')   AS fee
FROM race_demo
\gset
\echo 'Loaded: session=' :sess ' Chiamaka(ca)=' :ca ' Yusuf(cb)=' :cb ' Grace(cc)=' :cc ' seats=' :seat :seat2 :seat3
