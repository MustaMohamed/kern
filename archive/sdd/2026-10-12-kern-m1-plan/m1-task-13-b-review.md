### Spec Compliance

Method: fresh `git archive 30ab32f`, `t13/run.sh` with `protected_targets: v1-host, prod-db.internal, 127.0.0.1:3307`, `KERN_GUARDS=g13`, `/bin/bash` 3.2, BWK awk 20200816; about 230 mostly new probes, none run for real.

- ✅ Ruling (1), ssh: 52 of my 55 new write shapes deny (`bash -c`, `eval`, functions, `find -exec`, `xargs`, `sshpass`, bastion chains, `-oRemoteCommand`, `d^el`, PowerShell backtick, `(…).Delete()`, `-enc`, `>nul:`).
- ✅ (2) SQL: multi-`-e`, `/*!…*/`, escape lexing, `delimiter`, `EXPLAIN ANALYZE DELETE`, `--init-command`, `\gexec`, `COPY … PROGRAM` and sqlcmd `EXEC` all deny.
- ✅ (3) host:port. Attached and separate `-h`/`-P`, `--protocol=tcp` with no host, conninfo strings and the env forms all deny. The exceptions are in issue 2.
- ✅ (4)-(5) transfers: 34 of 35 write shapes deny (`host:`, `C:\` paths, `-3`, `-o HostName`, `::module`, `--remove-sent-files`, `--remote-option`, `printf 'p''ut'`, `-b -`, `-put`).
- ✅ (6) heads: path, case and `.exe` all hold. ✅ (7) all 11 `p-g13fp` lines give no vote. ✅ (8) the scope note is at the file head (`g13-protected.sh:11-13`).
- ⚠️ No MySQL, psql, PowerShell or Windows host here: issues 2-4 rest on client and shell behaviour I did not run.

### Strengths

- It proves a read rather than guessing at writes: unknown heads, PowerShell switches, unreadable files and run-time text deny.
- The awk fails closed: a non-zero exit votes deny (`g13-protected.sh:120-126`). I saw no awk error in about 230 probes on BWK.
- Prefilter superset: all 31 judged names (ssh, scp, sftp, rsync, and 27 SQL clients) contain one of the 10 prefilter substrings. It runs after `\u` decoding with quotes and backslashes removed (`:19-23`, `:48-56`); the only gap is in issue 6.
- Cost is flat or better than 21fa0bd (20 runs, all guards):

| Command | 21fa0bd | 30ab32f |
|---|---|---|
| `ls` | 161 ms | 154 ms |
| `ssh … dir` | 193 ms | 166 ms |
| `mysql … SELECT` | 164 ms | 167 ms |
| a four-part chain | 264 ms | 255 ms |

The outlier is large SQL input (issue 5).

### Issues

#### Critical

None.

#### Important

1. **Programs outside the client list that name a target get no vote.** I probed 11, and all 11 gave no vote:
   - SQL CLIs: `mycli -h 127.0.0.1 -P 3307 -e 'DELETE FROM t'`, `usql mysql://127.0.0.1:3307/db -c …`, `pgcli -h prod-db.internal -c …`.
   - Windows-native transfers: `curl -T a.txt smb://v1-host/c$/data/a.txt` (macOS's own curl lists smb), `smbclient //v1-host/c$ -c 'put …'`, `mount_smbfs //admin@v1-host/c$ …`, `lftp -e 'put …' sftp://v1-host`.
   - PowerShell remoting over ssh: `pwsh -c "Invoke-Command -HostName v1-host -ScriptBlock { Remove-Item … }"`.
   - ssh variants: `autossh -M 0 v1-host 'del …'` (it passes the prefilter, because it contains "ssh", but the judge does not treat it as ssh), `plink`, `mosh`.

   SMB is the natural write path to a Windows host. Each names the target in its own arguments, so this is not the "scripts that connect on their own" limit.

   Fix: judge `autossh` and `plink` as ssh. For a closed list of network clients (mycli, pgcli, usql, litecli, curl, wget, smbclient, mount_smbfs, lftp, ftp, mosh, pwsh/powershell with `-ComputerName`/`-HostName`, nc), deny when any word names a target (`named()`, or host:port). Cheap and safe: it only adds denies when a target is named.

2. **The tunnel's host:port has escapes (`:183`, `:724`).** Each of these gives no vote:
   - Loopback spellings: `mysql -h 0.0.0.0 -P 3307 -e 'DELETE FROM t'`, `-h 0`, `-h 127.1`, `-h ::ffff:127.0.0.1`. All reach a tunnel bound to 127.0.0.1.
   - Abbreviated long options: `mysql --hos=127.0.0.1 --por=3307 -e …`, `mysql -h 127.0.0.1 --po=3307 -e …`, and `psql --hos=… --por=… -c …`. MySQL's option parser accepts unambiguous prefixes in its clients (only mysqld turns that off), and getopt_long does the same for psql.

   Named-host targets are safe (`fb()` catches the bare host); host:port entries, the real use, are not.

   Fix: `canon` maps 0.0.0.0, 0, 127.0.0.0/8 and `::ffff:127.*` to localhost; an unambiguous prefix of `--host`/`--port` counts as that option. Cheap and safe.

3. **ssh connection sharing gets no vote.** `ssh -S ~/.ssh/cm-v1 x 'del C:\data\x'` and `ssh -o ControlPath=… x '…'` give no vote, because the destination `x` is not a target. OpenSSH's mux client sends the session over the socket, so the master runs it, and the master was opened on v1-host. Opening that master is allowed today: G13 exempts `ssh -M -S sock -fN v1-host` because of `-N` (`:346`). I did not run this against a live master.

   Fix: an ssh with `-S`, `ControlPath` or `ControlMaster`, whose destination is not a target, is judged as on a target (deny unless the command is proven read) whenever targets are set. Cheap; false denies only for multiplexed ssh to other hosts.

4. **A carriage return is not a separator (`:242`).** These give no vote:
   - `ssh v1-host 'dir C:\x<CR>Remove-Item C:\x'`
   - `ssh v1-host 'powershell -c dir C:\x<CR>Remove-Item C:\x'`

   I sent the CR as a JSON `\r` and as `\u000d`. The split set is `[;&|\n\037(){}\`]`. PowerShell ends a statement at a CR, so this is a write whenever the CR reaches PowerShell: either through an explicit `powershell -c`, or through a host whose OpenSSH DefaultShell is PowerShell. A LF is already handled.

   Fix: add `\r` to the split set, and deny any other control character in a remote command. Cheap and safe.

#### Minor

5. **Large SQL input is quadratic (`:539-545`, `:650`).** `slurp` and `sqlstrip` build strings a character or line at a time: G13 takes 0.26 s on 60 KB, 3.4 s on 300 KB and 54 s on 1.2 MB of `mysql … < f.sql`. Past 20 s the hook times out. `hooks.json` sets `onFailure: block`, so a dump restore to the target still fails closed (config only; not run in Claude Code). Files are also read before the target is known, so a 1.2 MB `psql -f` to a non-target costs 1.2 s, and a larger one would block a harmless local call.

   Fix: resolve the target first; read files only for a target; cap the size (deny above it); build strings in arrays.

6. **False denies on permitted reads not listed in section B, plus one name split:**
   - (a) Backslash-newline continuation. `ssh v1-host \⏎ 'dir C:\data'` and `mysql -h 127.0.0.1 \⏎ -P 3307 \⏎ -e 'SELECT 1'` deny "input piped". `_g13_fed` cannot find the rebuilt record, so it treats the record as fed (`:74`). This is the usual shape for long commands. The same root lets `s\⏎sh v1-host 'del …'` past both the prefilter and the judge. Fix: drop backslash-newline pairs before the prefilter and the scan.
   - (b) `Format-Table`, `Format-List`, `(Get-Item x).CreationTime`, `Get-Service`, `more` and `tasklist` deny; the first three do the CreationTime/LastWriteTime check the user's V1 rule asks for (`dir /T:C` works). Fix: add format-table, format-list, ft, fl and `get-*`, and allow a `.Name` segment that no `(` follows.
   - (c) `sftp v1-host:/data/x.pdf ./`, a copy from the target, denies as "interactive" (`:919`). Fix: one host:path operand counts as a get.

### Assessment

**Task quality:** Needs fixes. The judges hold against almost every new shape and fail closed, but writes still pass four cheap gaps: unlisted clients (SMB above all), loopback and abbreviated forms of the tunnel's host:port, ssh connection sharing, and a CR in a PowerShell command.
