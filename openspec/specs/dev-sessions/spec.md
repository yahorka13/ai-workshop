# dev-sessions Specification

## Purpose
A developer's or agent's local stack: one isolated session slot per worktree, its local configuration, the commands that check the machine, start, stop, remove and read the stack, and how Orca workspaces set it up and clean it away.

## Requirements

### Requirement: Only an example env file is committed
The repository SHALL commit `.env.example`, naming every variable of the local stack, while `.env` stays untracked.

#### Scenario: [dev-sessions-bd285f] The example is tracked and the local file is not
- **WHEN** the repository's tracked files and ignore rules are read
- **THEN** `.env.example` is tracked, `.env` is not tracked and is ignored, and every line of `.env.example` is a comment, a blank line or a `NAME=value` line whose generated values are left empty

### Requirement: Setup writes a local env file
`bin/setup-env.sh` SHALL write `.env` from `.env.example` when it does not exist, copying each value the example sets and generating 32 random lowercase hex characters for each value it leaves empty.

#### Scenario: [dev-sessions-057e31] A fresh checkout gets its env file
- **WHEN** `bin/setup-env.sh` runs in a checkout without `.env`
- **THEN** `.env` holds every variable of `.env.example`, the set values copied without their comments and each empty one as 32 lowercase hex characters, and it exits 0

#### Scenario: [dev-sessions-e13300] Generated values differ per checkout
- **WHEN** `bin/setup-env.sh` runs in two checkouts without `.env`
- **THEN** the generated values of the two `.env` files differ

### Requirement: The local env file is private
`bin/setup-env.sh` SHALL write `.env` readable and writable only by its owner.

#### Scenario: [dev-sessions-01e6a1] The env file has mode 600
- **WHEN** `bin/setup-env.sh` writes `.env`
- **THEN** the file's mode is 600

### Requirement: Setup never rotates an existing value
When `.env` exists, `bin/setup-env.sh` SHALL keep every value in it and append only the variables `.env.example` names that `.env` lacks, naming each one it added.

#### Scenario: [dev-sessions-6bb305] A rerun changes nothing
- **WHEN** `bin/setup-env.sh` runs twice
- **THEN** `.env` is the same after the second run and the output says it is up to date

#### Scenario: [dev-sessions-0b0d6c] A new variable is added and old values are kept
- **WHEN** `.env.example` gains a variable after `.env` was written and `bin/setup-env.sh` runs again
- **THEN** `.env` keeps every earlier value, gains the new variable and the output names it

### Requirement: bin/setup writes the env file
`bin/setup` SHALL run its steps in this order: the git hooks, the local `.env`, then the Claude Code plugins.

#### Scenario: [dev-sessions-cd162d] Setup writes the env file between hooks and plugins
- **WHEN** `bin/setup` runs in a checkout without `.env`
- **THEN** the git hooks are enabled, then `.env` is written, then the plugins step runs, and it exits 0

### Requirement: bin/doctor reports each check
`bin/doctor` SHALL print one line per check, marked `ok`, `warn` or `FAIL`, with a `fix:` line under each `warn` and `FAIL` saying how to fix it.

#### Scenario: [dev-sessions-a9db7c] A ready machine passes
- **WHEN** `bin/doctor` runs with git, a running Docker with Compose 2.22 or newer, `ss` or `lsof`, an authenticated `gh`, `claude`, `orca`, Node 24 or newer, a `.env` and the repository hooks enabled
- **THEN** every line is marked `ok` and it exits 0

### Requirement: bin/doctor fails on a missing prerequisite
`bin/doctor` SHALL exit 1 when git, Docker, a running Docker daemon, Docker Compose 2.22 or newer, `ss` or `lsof`, or an authenticated `gh` is missing.

#### Scenario: [dev-sessions-60b984] Missing Docker names the install
- **WHEN** `bin/doctor` runs without `docker` on `PATH`
- **THEN** the Docker line is marked `FAIL`, its fix names how to install Docker on the platform, and it exits 1

#### Scenario: [dev-sessions-a1857d] A stopped daemon, an old Compose or no port tool fails
- **WHEN** `bin/doctor` runs and the Docker daemon does not answer, or Compose is older than 2.22, or neither `ss` nor `lsof` is on `PATH`
- **THEN** that line is marked `FAIL` with its fix and it exits 1

#### Scenario: [dev-sessions-88c848] An unauthenticated gh fails with the login command
- **WHEN** `bin/doctor` runs and `gh auth status` fails
- **THEN** the gh line is marked `FAIL`, its fix is `gh auth login`, and it exits 1

### Requirement: bin/doctor only warns about optional tools
`bin/doctor` SHALL mark a missing `claude` or `orca`, a missing `.env` or disabled repository hooks as `warn`, a mark that alone never makes it fail.

#### Scenario: [dev-sessions-651c80] Optional tools only warn
- **WHEN** `bin/doctor` runs on an otherwise ready machine without `claude`, without `orca`, without `.env` and without the repository hooks enabled
- **THEN** those lines are marked `warn`, the `.env` and hooks fixes name `bin/setup`, and it exits 0

### Requirement: bin/doctor checks WSL specifics
On WSL, `bin/doctor` SHALL fail a checkout under the Windows filesystem (`/mnt/<drive>/`) and warn when git's `core.autocrlf` is `true`.

#### Scenario: [dev-sessions-13f369] A checkout on the Windows drive fails on WSL
- **WHEN** `bin/doctor` runs on WSL in a checkout under `/mnt/c/`
- **THEN** that line is marked `FAIL`, its fix says to clone into the Linux home directory, and it exits 1

#### Scenario: [dev-sessions-472c77] autocrlf only warns on WSL
- **WHEN** `bin/doctor` runs on WSL in a checkout in the Linux home with `core.autocrlf` set to `true`
- **THEN** that line is marked `warn` and it exits 0

#### Scenario: [dev-sessions-2af609] No WSL checks elsewhere
- **WHEN** `bin/doctor` runs outside WSL
- **THEN** it prints no WSL line

### Requirement: Setup and doctor describe themselves
`bin/setup-env.sh` and `bin/doctor` SHALL print their usage with `--help`, exit 0 and change nothing, without Docker.

#### Scenario: [dev-sessions-40df32] Help needs nothing
- **WHEN** `bin/setup-env.sh --help` or `bin/doctor --help` runs without `docker` on `PATH` in a checkout without `.env`
- **THEN** it exits 0, prints its usage and no `.env` is written

### Requirement: Basic Compose topology
The root `docker-compose.yml` SHALL default to project `factory` and run PostgreSQL on its official image, configured by `POSTGRES_USER`, `POSTGRES_DB` and `POSTGRES_PASSWORD` from the environment, with its data in a named volume.

#### Scenario: [dev-sessions-2e17aa] Postgres takes its credentials from the environment
- **WHEN** the base Compose file is rendered with `POSTGRES_USER`, `POSTGRES_DB` and `POSTGRES_PASSWORD` set and no project name
- **THEN** the project is `factory`, the `postgres` service runs the official `postgres` image with those three values and a health check, and its data directory is a named volume

### Requirement: Published ports live only in the session file
Host ports SHALL be published only by `docker-compose.session.yml`, on the session's bind host.

#### Scenario: [dev-sessions-f200dc] No ports without the session file
- **WHEN** the base and local Compose files are rendered without the session file
- **THEN** no service publishes a host port

### Requirement: Every local service has hard limits
Every service of a stack `bin/compose` runs SHALL have a CPU limit of at most 2 CPUs and a memory limit.

#### Scenario: [dev-sessions-069f42] Every local service is limited
- **WHEN** the stack is rendered through `bin/compose config`
- **THEN** every service has a CPU limit of at most 2 and a memory limit

### Requirement: Containers share log and health check settings
Every container SHALL keep bounded log files, every health-checked service taking its timing from one shared settings block with its own probe.

#### Scenario: [dev-sessions-8e0ae4] Logs are bounded and health checks share their timing
- **WHEN** the Compose configuration is rendered
- **THEN** every container uses two log files of at most 8 MB, and every health check probes every 5s with a 5s start period, a 2s timeout and 3 retries

### Requirement: Each worktree holds one slot
`bin/session claim <path>` SHALL give each worktree one slot and return the same slot to the same worktree, however its path is spelled.

#### Scenario: [dev-sessions-52a056] Repeated claim returns the same slot
- **WHEN** a worktree claims a slot twice, once through a symlinked path to it
- **THEN** both claims return the same slot and the registry holds one entry for it

#### Scenario: [dev-sessions-13071c] Another worktree gets the next free slot
- **WHEN** slot 1 is held by one worktree and a second worktree claims
- **THEN** the second worktree receives slot 2

### Requirement: Slot count is bounded
Slots SHALL be bounded by `FACTORY_SESSION_SLOTS`, 3 by default and from 1 to 10.

#### Scenario: [dev-sessions-2d3049] Exhausted slots fail with their holders
- **WHEN** every slot up to `FACTORY_SESSION_SLOTS` is held and another worktree claims
- **THEN** the claim exits nonzero, lists each slot with the worktree holding it and whether that worktree is `alive` or `stale`, and says that `bin/down` in a holder frees its slot and that `bin/session reap` removes stale ones

#### Scenario: [dev-sessions-f73589] The default is three slots
- **WHEN** `FACTORY_SESSION_SLOTS` is unset, three worktrees hold slots 1 to 3 and a fourth claims
- **THEN** the claim exits nonzero

#### Scenario: [dev-sessions-b52a96] Out-of-range slot limit is rejected
- **WHEN** `FACTORY_SESSION_SLOTS` is not a number from 1 to 10
- **THEN** the claim exits nonzero and names the allowed range

### Requirement: Concurrent claims never share a slot
Concurrent claims SHALL never receive the same slot.

#### Scenario: [dev-sessions-c9840d] Concurrent claims get distinct slots
- **WHEN** several worktrees claim at the same moment
- **THEN** each receives a different slot

### Requirement: A deleted worktree's slot is reclaimable
A slot whose worktree directory no longer exists SHALL be claimable by another worktree.

#### Scenario: [dev-sessions-c815af] Slot of a deleted worktree is reclaimed
- **WHEN** slot 1 is held by a worktree whose directory was deleted and another worktree claims
- **THEN** the new worktree receives slot 1 and `bin/session list` no longer shows the deleted path

### Requirement: Release spares another holder's slot
Releasing a slot with an expected worktree SHALL leave it claimed when another worktree holds it.

#### Scenario: [dev-sessions-f0bf93] Release leaves another holder's slot alone
- **WHEN** slot 1 is released naming worktree A while worktree B holds it
- **THEN** slot 1 stays claimed by B and the command says so

### Requirement: A dead holder's claim lock is broken
A slot registry lock whose recorded holder process is gone SHALL be broken by the next claim, with a warning.

#### Scenario: [dev-sessions-ccd8c1] Dead holder's lock is broken
- **WHEN** the lock names a process that no longer runs
- **THEN** a claim breaks the lock, warns that it did, and succeeds

### Requirement: A live holder's claim lock times out
A slot registry lock held by a live process SHALL make a claim fail after `FACTORY_LOCK_TIMEOUT` seconds with a message naming that process.

#### Scenario: [dev-sessions-b57a4e] Live holder's lock times out
- **WHEN** the lock is held by a running process past the timeout
- **THEN** the claim exits nonzero and names the holding process

### Requirement: Slot ports follow the slot number
Slot `n` SHALL own host ports `10100 + (n - 1) * 1000` through `11099 + (n - 1) * 1000`, with the UI on the block's first port, the API on the second and PostgreSQL on the third.

#### Scenario: [dev-sessions-18a82b] Ports follow the slot
- **WHEN** `bin/session ports 2` runs
- **THEN** it prints `FACTORY_PORT_UI=11100`, `FACTORY_PORT_API=11101` and `FACTORY_PORT_POSTGRES=11102`, and no other port

### Requirement: A claim skips a slot with a busy port
A claim SHALL skip a slot when any port of its block's named ports is already listening on the host.

#### Scenario: [dev-sessions-a48010] Busy Postgres port skips the slot
- **WHEN** slot 1 is free in the registry but port 10102 is listening on the host
- **THEN** a claim receives slot 2

#### Scenario: [dev-sessions-4789dd] Busy UI port skips the slot
- **WHEN** slot 1 is free in the registry but port 10100 is listening on the host
- **THEN** a claim receives slot 2

### Requirement: A claim skips a slot with leftover resources
A claim SHALL skip a slot whose Compose project still has containers or volumes.

#### Scenario: [dev-sessions-bf4071] Leftover volumes skip the slot
- **WHEN** slot 1 is free in the registry but a volume labelled with project `factory-1` exists
- **THEN** a claim receives slot 2

### Requirement: bin/compose layers the session's files
`bin/compose <args>` SHALL run Docker Compose with `docker-compose.yml`, `docker-compose.local.yml` and `docker-compose.session.yml` in that order, loading the worktree's `.env` and then its `.env.session`.

#### Scenario: [dev-sessions-02b749] Files are layered for the session
- **WHEN** `bin/compose config` runs in a worktree with a session in slot 2
- **THEN** Compose receives the three files in that order, both env files, and the project is `factory-2`

### Requirement: bin/compose needs a session
Without a session, `bin/compose` SHALL fail and say to run `bin/up`, without running Compose.

#### Scenario: [dev-sessions-7d683e] Missing session is reported
- **WHEN** `bin/compose ps` runs in a worktree without `.env.session`
- **THEN** it exits nonzero with "No session for this worktree — run bin/up" and Compose is not invoked

### Requirement: bin/up starts the stack and prints its URLs
`bin/up` SHALL claim the worktree's slot, start the stack in the background, wait until every health-checked service is healthy, and print the session, the project and one URL per published service, never a password.

#### Scenario: [dev-sessions-9bfe82] Stack starts and prints its URLs
- **WHEN** `bin/up` runs in a worktree that holds slot 2
- **THEN** the stack runs as project `factory-2`, every health check passes, the output contains `http://127.0.0.1:11100`, `http://127.0.0.1:11101/graphql` and `postgres://<POSTGRES_USER>@127.0.0.1:11102/<POSTGRES_DB>` and no other URL, and it does not contain the Postgres password

### Requirement: The session file is private
`bin/up` SHALL write `.env.session` with mode 600, holding the slot, the project name, the ports and the hosts.

#### Scenario: [dev-sessions-234ed4] Session file is private
- **WHEN** `bin/up` writes `.env.session`
- **THEN** the file has mode 600 and holds `FACTORY_SESSION_ID`, `COMPOSE_PROJECT_NAME`, every `FACTORY_PORT_*`, `FACTORY_PUBLIC_HOST` and `FACTORY_BIND_HOST`

### Requirement: Public and bind hosts are configurable
`bin/up` SHALL print URLs with `FACTORY_PUBLIC_HOST` and publish ports on `FACTORY_BIND_HOST`, both `127.0.0.1` by default and read from the environment or `~/.factory/env`.

#### Scenario: [dev-sessions-01b88b] Hosts come from the environment
- **WHEN** `FACTORY_PUBLIC_HOST` and `FACTORY_BIND_HOST` are exported before `bin/up`
- **THEN** printed URLs use the public host and published ports bind to the bind host

#### Scenario: [dev-sessions-76daa7] Hosts come from the machine env file
- **WHEN** neither is exported and `~/.factory/env` sets both
- **THEN** `bin/up` uses the values of that file

### Requirement: bin/up again reuses the slot
Running `bin/up` again SHALL reuse the worktree's slot and ports.

#### Scenario: [dev-sessions-5f2d9b] Second run reuses the slot
- **WHEN** `bin/up` runs again in the same worktree
- **THEN** it keeps the same slot and the same ports

### Requirement: bin/up starts a fresh checkout
`bin/up` SHALL write the local `.env` before it starts the stack when the checkout has none, so a fresh checkout needs no other command.

#### Scenario: [dev-sessions-35b81e] bin/up in a checkout without .env
- **WHEN** `bin/up` runs in a checkout without `.env`
- **THEN** `.env` is written from `.env.example` and the stack starts healthy

### Requirement: bin/up checks its prerequisites first
`bin/up` SHALL check that Docker is installed and running before it claims a slot, naming the fix of each failure.

#### Scenario: [dev-sessions-ca988c] Missing Docker is named
- **WHEN** `docker` is not on `PATH`, or Docker is not running, and `bin/up` runs
- **THEN** `bin/up` exits nonzero naming the problem and its fix, and claims no slot

### Requirement: An unhealthy bin/up keeps its slot
When the stack does not become healthy, `bin/up` SHALL exit nonzero, print the recent logs of each service that is not running or not healthy, and keep the slot.

#### Scenario: [dev-sessions-b256e0] Unhealthy stack keeps its slot and shows logs
- **WHEN** a service fails its health check during `bin/up`
- **THEN** `bin/up` exits nonzero, prints that service's recent logs, and the slot and `.env.session` remain

### Requirement: A bin/up that started nothing releases its slot
When nothing of the project exists after a failed start, `bin/up` SHALL release the slot and remove `.env.session`.

#### Scenario: [dev-sessions-0ad372] Failed start with nothing left releases the slot
- **WHEN** the start fails before any container or volume of the project exists
- **THEN** `bin/up` exits nonzero, the slot is released and `.env.session` is removed

### Requirement: bin/up --watch rebuilds on change
`bin/up --watch` SHALL, once the stack is healthy, stay attached to a Compose watch of the stack until interrupted.

#### Scenario: [dev-sessions-fe78a8] bin/up --watch stays attached and syncs
- **WHEN** `bin/up --watch` runs on a stack with a service that watches a path, and a file under that path changes
- **THEN** the command stays attached and the changed file reaches that service's container

### Requirement: Nothing to watch is not an error
When no service of the stack watches a path, `bin/up --watch` and `bin/session watch-start` SHALL say there is nothing to watch and exit 0 without starting a watch.

#### Scenario: [dev-sessions-1f72de] A stack without watched services
- **WHEN** `bin/up --watch` or `bin/session watch-start` runs on a stack whose services watch nothing
- **THEN** it says there is nothing to watch, starts no watch and exits 0

### Requirement: bin/stop keeps the stack's data
`bin/stop` SHALL stop the worktree's containers and keep its volumes, slot and `.env.session`, doing nothing and exiting 0 without a session.

#### Scenario: [dev-sessions-ae7e18] Data survives stop and up
- **WHEN** a row is written to the stack's Postgres, then `bin/stop` and `bin/up` run
- **THEN** the row is still there and the slot is unchanged

#### Scenario: [dev-sessions-5da8d7] Stop without a session
- **WHEN** `bin/stop` runs in a worktree without a session
- **THEN** it says there is nothing to stop and exits 0

### Requirement: bin/logs reads the worktree's logs
`bin/logs [service] [flags]` SHALL show the logs of the worktree's stack, or of one service, passing Compose log flags through unchanged.

#### Scenario: [dev-sessions-ae2dd8] Flags pass through
- **WHEN** `bin/logs postgres -f --since 5m` runs
- **THEN** Compose receives `logs postgres -f --since 5m` for the worktree's project

### Requirement: Isolated stacks side by side
Stacks of different worktrees SHALL NOT share containers, volumes, networks or host ports.

#### Scenario: [dev-sessions-61e5a3] Two worktrees run isolated stacks
- **WHEN** two worktrees each run `bin/up` at the same time
- **THEN** they hold different slots and ports, and a table created in one stack's Postgres does not exist in the other's

### Requirement: bin/down removes everything of its stack
`bin/down` SHALL remove the worktree's containers, volumes, networks and images labelled with its project, including any outside Compose's view, delete `.env.session` and release the slot.

#### Scenario: [dev-sessions-34b617] Nothing is left behind
- **WHEN** `bin/down` runs in a worktree whose stack is running
- **THEN** no container, volume, network or image labelled with its project remains, `.env.session` is gone and the slot is free

### Requirement: bin/down leaves other projects alone
`bin/down` SHALL NOT touch the stack of another worktree.

#### Scenario: [dev-sessions-822f79] Other stacks are untouched
- **WHEN** two worktrees run stacks and `bin/down` runs in one of them
- **THEN** the other stack keeps running with its data

#### Scenario: [dev-sessions-578c95] A stale session file removes nothing
- **WHEN** `.env.session` names a slot the registry gives to another existing worktree and `bin/down` runs
- **THEN** it exits nonzero naming that worktree, and removes nothing

### Requirement: bin/down without a session succeeds
`bin/down` SHALL exit 0 with a message when there is nothing to remove.

#### Scenario: [dev-sessions-d05dd0] No session is not an error
- **WHEN** `bin/down` runs in a worktree without a session
- **THEN** it says there is nothing to tear down and exits 0

### Requirement: bin/down without Docker keeps the slot
When Docker is not running, `bin/down` SHALL exit nonzero and keep the slot and `.env.session`.

#### Scenario: [dev-sessions-3e4b5f] Docker down keeps the session
- **WHEN** `bin/down` runs in a worktree with a session while Docker is not running
- **THEN** it exits nonzero saying to start Docker, and the slot and `.env.session` remain

### Requirement: Abandoned stacks are reaped
`bin/session reap` SHALL remove everything labelled with every `factory-<slot>` project whose worktree no longer exists and free a slot held by that missing worktree, printing each project it removed.

#### Scenario: [dev-sessions-27f723] A deleted worktree's stack is removed
- **WHEN** a worktree with a running stack is deleted without `bin/down` and `bin/session reap` runs
- **THEN** no container, volume, network or image labelled with its project remains, its slot is free in `bin/session list`, and the output names the removed project

#### Scenario: [dev-sessions-af5011] A live worktree's stack is never removed
- **WHEN** `bin/session reap` runs and a project's containers name a working directory that exists, even if the registry holds its slot for a missing worktree or for none
- **THEN** that project keeps running with its data

#### Scenario: [dev-sessions-67961b] Reap without Docker changes nothing
- **WHEN** `bin/session reap` runs while Docker is not running
- **THEN** it says Docker is not available, removes nothing, frees no slot and exits 0

### Requirement: bin/up reaps before claiming
`bin/up` SHALL run `bin/session reap` before it claims a slot.

#### Scenario: [dev-sessions-daaa07] A leaked stack's slot goes to the next bin/up
- **WHEN** a worktree is deleted without `bin/down` while its stack runs, and `bin/up` runs in another worktree
- **THEN** the deleted worktree's stack is removed

### Requirement: The background watch runs detached
`bin/session watch-start <slot> <worktree>` SHALL run the worktree's Compose watch in the background, detached from the caller, appending its output to `~/.factory/orca-watch-<slot>.log`, and return once Compose says it is watching.

#### Scenario: [dev-sessions-6834b6] watch-start leaves a watch running
- **WHEN** `bin/session watch-start` runs for a worktree whose stack watches a path
- **THEN** after it returns, a Compose watch of that worktree's stack runs and writes to `~/.factory/orca-watch-<slot>.log`

#### Scenario: [dev-sessions-80e03e] A watch that never starts fails
- **WHEN** the watch exits, or does not say it is watching within `FACTORY_WATCH_START_TIMEOUT` seconds
- **THEN** `watch-start` stops it, exits nonzero and names the log

### Requirement: Starting a watch again keeps one watch
`bin/session watch-start` SHALL replace the slot's running watch, never add a second one.

#### Scenario: [dev-sessions-e6c033] watch-start twice keeps one watch
- **WHEN** `bin/session watch-start` runs twice for the same slot
- **THEN** exactly one Compose watch of that worktree's stack runs

### Requirement: Stopping or removing the stack stops its watch
`bin/stop`, `bin/down` and `bin/session reap` SHALL stop the background watch of the slot they stop or remove.

#### Scenario: [dev-sessions-070ab5] bin/stop ends the watch
- **WHEN** a worktree's background watch runs and `bin/stop` runs
- **THEN** no watch of that worktree remains and the stack's data and slot are kept

#### Scenario: [dev-sessions-afe93a] Reap ends a deleted worktree's watch
- **WHEN** a worktree with a running watch is deleted without `bin/down` and `bin/session reap` runs
- **THEN** no watch of that worktree remains

### Requirement: Only the recorded watch is signalled
`bin/session watch-stop` SHALL signal a recorded process only while it is still a Compose watch, and forget the record either way.

#### Scenario: [dev-sessions-f6e826] A recycled process is left alone
- **WHEN** the recorded watch has exited and its process ID now belongs to another process, and `bin/down` runs
- **THEN** that other process keeps running and the record is removed

### Requirement: Session commands describe themselves
`bin/session`, `bin/compose`, `bin/up`, `bin/stop`, `bin/down` and `bin/logs` SHALL print their usage and prerequisites with `--help`, without contacting Docker.

#### Scenario: [dev-sessions-f6d714] Help needs nothing
- **WHEN** any session command runs with `--help` and Docker is not available
- **THEN** it exits 0 and prints its usage

### Requirement: Session scripts are portable
The session scripts SHALL run on macOS's Bash 3.2 with BSD tools and on Linux with GNU tools.

#### Scenario: [dev-sessions-8ae377] Same scripts on macOS and Linux
- **WHEN** the session script tests run on macOS and in the Linux CI runner
- **THEN** they pass on both without platform-specific flags

### Requirement: Session scripts pass shellcheck
CI's shellcheck step SHALL check every session script and fail on any finding.

#### Scenario: [dev-sessions-02ec45] CI shellchecks the session scripts
- **WHEN** CI's repository checks run
- **THEN** its shellcheck step checks `bin/session`, `bin/compose`, `bin/up`, `bin/stop`, `bin/down` and `bin/logs`

### Requirement: CI proves the stacks on Docker
CI SHALL run the Docker-backed sessions proof on every pull request and remove its stacks even when the job is cancelled.

#### Scenario: [dev-sessions-471c88] The sessions proof runs in CI
- **WHEN** CI runs on a pull request
- **THEN** a `sessions-proof` job runs `bin/tests/sessions.e2e.sh`, and a step that always runs removes the stacks of its worktrees

### Requirement: Orca hooks run the workspace's own scripts
The repository SHALL provide an `orca.yaml` whose setup and archive hooks run the hook scripts of the workspace's own checkout (`$ORCA_WORKTREE_PATH`), never the main checkout's, with an agent startup policy that opens the agent at once, beside setup.

#### Scenario: [dev-sessions-2468d4] Orca config wires the hooks
- **WHEN** the repository's `orca.yaml` is read
- **THEN** its setup hook runs the workspace's `bin/orca-setup` and its archive hook the workspace's `bin/orca-archive`, neither refers to `$ORCA_ROOT_PATH`, and `setupAgentStartupPolicy` is `start-immediately`

### Requirement: No Orca issue command
The repository SHALL configure no Orca issue command, neither in `orca.yaml` nor as a tracked `.orca/issue-command`.

#### Scenario: [dev-sessions-0388a7] No issue command is configured
- **WHEN** the repository's `orca.yaml` and tracked files are read
- **THEN** `orca.yaml` has no `issueCommand` and no `.orca/issue-command` is tracked

### Requirement: Every agent reads the issue-URL rule
Every agent's instruction file SHALL load AGENTS.md, which maps a prompt that is only an issue URL of this repository to `/work <N>` and names the work skill's file for agents without the command.

#### Scenario: [dev-sessions-2d7182] Claude and Gemini load the rule
- **WHEN** `CLAUDE.md`, `GEMINI.md` and `AGENTS.md` are read
- **THEN** both entry files load `@AGENTS.md`, AGENTS.md maps `https://github.com/<owner>/<repo>/issues/<N>` to `/work <N>` and names `.claude/skills/work/SKILL.md`, and that file exists

### Requirement: Orca setup starts the workspace's stack
`bin/orca-setup` SHALL run the `bin/setup` and then the `bin/up` of the workspace at `$ORCA_WORKTREE_PATH` (the current directory when unset), exiting 0 only once the stack is healthy.

#### Scenario: [dev-sessions-49530f] Setup brings the stack up
- **WHEN** `bin/orca-setup` runs for a new workspace
- **THEN** the workspace's `bin/setup` runs, then its `bin/up`, and the hook exits 0

#### Scenario: [dev-sessions-35f075] Setup defaults to the current directory
- **WHEN** `bin/orca-setup` runs without `ORCA_WORKTREE_PATH` inside a workspace
- **THEN** it runs that workspace's `bin/setup` and `bin/up`

#### Scenario: [dev-sessions-c7336e] A stack that does not come up fails setup
- **WHEN** the workspace's `bin/setup` or `bin/up` exits nonzero
- **THEN** `bin/orca-setup` exits nonzero with that output, opens no browser tab, starts no watch and starts no `bin/orca-autostart`

### Requirement: Orca setup opens the UI
Once the stack is healthy, `bin/orca-setup` SHALL open `http://<FACTORY_PUBLIC_HOST>:<FACTORY_PORT_UI>` in an Orca browser tab of that workspace when the stack has a `ui` service.

#### Scenario: [dev-sessions-e35f4d] A stack with a UI gets its tab
- **WHEN** `bin/orca-setup` runs for a workspace whose stack has a `ui` service
- **THEN** one Orca browser tab opens at the UI URL from `.env.session`, selected by `ORCA_WORKTREE_ID` when set and by the workspace path otherwise

#### Scenario: [dev-sessions-e1aa32] A stack without a UI opens no tab
- **WHEN** `bin/orca-setup` runs for a workspace whose stack has no `ui` service
- **THEN** no Orca tab is opened and the hook exits 0

#### Scenario: [dev-sessions-06ec9c] The Orca CLI is found outside PATH
- **WHEN** `orca` is not on `PATH` but `ORCA_CLI_BIN_DIR` names its directory
- **THEN** `bin/orca-setup` opens the tab through that CLI

### Requirement: Orca setup tabs are best-effort
A tab `bin/orca-setup` cannot open SHALL make it print a note naming the URL and still exit 0.

#### Scenario: [dev-sessions-8baa19] A failed browser tab does not fail setup
- **WHEN** the stack is healthy but the Orca CLI is missing or cannot open the tab
- **THEN** `bin/orca-setup` prints a note naming the URL and exits 0

### Requirement: Orca setup starts a background watch
After the workspace's stack is up, `bin/orca-setup` SHALL start the slot's background watch with `bin/session watch-start`.

#### Scenario: [dev-sessions-8f5568] Setup leaves a watch running
- **WHEN** `bin/orca-setup` runs for a workspace whose stack watches a path
- **THEN** after the hook exits, a Compose watch of that workspace's stack is running

#### Scenario: [dev-sessions-d773fd] Setup again keeps one watch
- **WHEN** `bin/orca-setup` runs twice for the same workspace
- **THEN** exactly one Compose watch of that workspace's stack is running

### Requirement: A watch that cannot start does not fail setup
A watch that cannot start SHALL make `bin/orca-setup` print a note saying the stack is not watching, and still exit 0.

#### Scenario: [dev-sessions-27c10c] A watch that cannot start does not fail setup
- **WHEN** the stack is up but the watch cannot be started
- **THEN** `bin/orca-setup` prints a note saying the stack is not watching its sources and exits 0

### Requirement: Orca setup starts the issue autostart
`bin/orca-setup` SHALL start the workspace's `bin/orca-autostart` in the background as its last step, detached so it outlives the hook, logging to `~/.factory/orca-autostart.log`.

#### Scenario: [dev-sessions-8facfe] The helper outlives setup
- **WHEN** `bin/orca-setup` exits 0
- **THEN** the workspace's `bin/orca-autostart` is still running, or has written its log line to `~/.factory/orca-autostart.log`

### Requirement: Autostart submits a bare issue URL
`bin/orca-autostart` SHALL press Enter in the workspace's one Claude terminal whose draft is exactly `https://github.com/<owner>/<repo>/issues/<N>` for the repository `bin/repo` prints.

#### Scenario: [dev-sessions-a8fef1] A bare issue URL draft is submitted
- **WHEN** one Claude terminal of the workspace holds the draft `https://github.com/<owner>/<repo>/issues/4`
- **THEN** `bin/orca-autostart` sends Enter to that terminal and exits 0

#### Scenario: [dev-sessions-3ffdfc] A draft that appears later is submitted
- **WHEN** the draft appears after a few polls, within the timeout
- **THEN** `bin/orca-autostart` sends Enter to that terminal once and exits 0

### Requirement: Autostart leaves other drafts alone
`bin/orca-autostart` SHALL send nothing when a Claude terminal holds any other draft, or when more than one holds an issue URL of this repository.

#### Scenario: [dev-sessions-e3bd9c] Other drafts are left untouched
- **WHEN** the draft is an issue URL of another repository, or an issue URL followed by more text
- **THEN** `bin/orca-autostart` sends nothing and exits 0

#### Scenario: [dev-sessions-2afb11] Two matching terminals are left untouched
- **WHEN** two Claude terminals of the workspace each hold an issue URL of this repository
- **THEN** `bin/orca-autostart` sends nothing and exits 0

### Requirement: Autostart gives up quietly
`bin/orca-autostart` SHALL exit 0 without sending anything when no matching draft appears within `FACTORY_AUTOSTART_TIMEOUT` seconds or no Orca CLI is found.

#### Scenario: [dev-sessions-5b0ac4] No draft within the bound
- **WHEN** no Claude terminal holds a draft until the timeout
- **THEN** `bin/orca-autostart` sends nothing, logs that it found no draft and exits 0

#### Scenario: [dev-sessions-b5e9a6] No Orca CLI
- **WHEN** `bin/orca-autostart` runs without `orca` on `PATH` or in `ORCA_CLI_BIN_DIR`
- **THEN** it logs that there is no Orca CLI and exits 0

### Requirement: Orca archive removes the workspace's stack
`bin/orca-archive` SHALL run the `bin/down` of the workspace at `$ORCA_WORKTREE_PATH` (the current directory when unset) and exit with its status.

#### Scenario: [dev-sessions-814c8b] Archive removes the stack and frees the slot
- **WHEN** a workspace with a running stack and a running watch is archived
- **THEN** its containers, volumes and networks are removed, no watch of it remains, its slot is free in `bin/session list`, and the hook exits 0

#### Scenario: [dev-sessions-58db50] Archive without a session succeeds
- **WHEN** a workspace that never started a stack is archived
- **THEN** `bin/orca-archive` exits 0 without removing anything

#### Scenario: [dev-sessions-b8d551] Archive that cannot remove the stack fails
- **WHEN** the workspace's `bin/down` exits nonzero, for example because Docker is not running, or the workspace has no `bin/down`
- **THEN** `bin/orca-archive` exits nonzero with that output and the slot is kept

### Requirement: Orca hooks log their start and finish
`bin/orca-setup` and `bin/orca-archive` SHALL append a line to `~/.factory/orca-hooks.log` (`$FACTORY_ORCA_HOOK_LOG` when set) when they start and another when they finish, each with a timestamp, the hook name, the workspace and its slot when known, the last with the exit status.

#### Scenario: [dev-sessions-518d81] Archive run is logged with its status
- **WHEN** `bin/orca-archive` runs for a workspace and its `bin/down` succeeds
- **THEN** the log gains a `started` line and an `exited 0` line naming `archive`, the workspace and its slot

#### Scenario: [dev-sessions-7c67ee] Setup run is logged
- **WHEN** `bin/orca-setup` runs for a workspace
- **THEN** the log gains a `started` line and an `exited <status>` line naming `setup` and the workspace

### Requirement: Logging keeps the hook's exit status
Logging SHALL NOT change an Orca hook's exit status, even when the log cannot be written.

#### Scenario: [dev-sessions-77bfa7] Failed hook is logged and still fails
- **WHEN** `bin/orca-archive` runs and the workspace's `bin/down` exits nonzero, or the hook log's directory cannot be created
- **THEN** the hook exits with `bin/down`'s status, and the log, when writable, records that status

### Requirement: Orca hook scripts pass shellcheck
CI's shellcheck step SHALL check `bin/orca-setup`, `bin/orca-archive` and `bin/orca-autostart` and fail on any finding.

#### Scenario: [dev-sessions-2a2c77] CI shellchecks the Orca hooks
- **WHEN** CI's repository checks run
- **THEN** its shellcheck step checks `bin/orca-setup`, `bin/orca-archive` and `bin/orca-autostart`

### Requirement: The stack runs the backend
The root `docker-compose.yml` SHALL run a `backend` service built from `services/backend`'s runtime target, configured from `.env`, started once Postgres is healthy, with a health check on its `/health` endpoint.

#### Scenario: [dev-sessions-3ee331] The backend is in the stack
- **WHEN** the base Compose file is rendered with `.env` set
- **THEN** the `backend` service builds `services/backend` at target `runtime`, receives `POSTGRES_USER`, `POSTGRES_DB` and `POSTGRES_PASSWORD` with Postgres as its host, depends on `postgres` being healthy, and has a health check that requests `/health`

### Requirement: Editing the backend's source rebuilds it
The `backend` service SHALL declare a Compose watch that rebuilds it when a file under `services/backend/src/`, its manifest or its lockfile changes.

#### Scenario: [dev-sessions-a965a8] The backend watches its source
- **WHEN** the stack is rendered through `bin/compose config`
- **THEN** the `backend` service has a `rebuild` watch on `services/backend/src`, `package.json` and `bun.lock`

### Requirement: The stack runs the UI
The root `docker-compose.yml` SHALL run a `ui` service built from `services/ui`'s runtime target, with a health check on its entry page.

#### Scenario: [dev-sessions-b93c17] The UI is in the stack
- **WHEN** `bin/up` has started a worktree's stack
- **THEN** the `ui` service is healthy and `http://<FACTORY_PUBLIC_HOST>:<FACTORY_PORT_UI>/` answers 200 with the app's entry page

### Requirement: Editing the UI rebuilds it
The `ui` service SHALL declare a Compose watch that rebuilds it when a file under `services/ui/` changes, ignoring tests, coverage, installed modules, build output and its `AGENTS.md`.

#### Scenario: [dev-sessions-9fb5b8] The UI watches its source
- **WHEN** the stack is rendered through `bin/compose config`
- **THEN** the `ui` service has a `rebuild` watch on `services/ui` that ignores `node_modules/`, `coverage/`, `dist/`, `tests/` and `AGENTS.md`

### Requirement: The UI calls its own stack's API
A stack's UI SHALL be built with the API origin of the same slot, `http://<FACTORY_PUBLIC_HOST>:<FACTORY_PORT_API>`.

#### Scenario: [dev-sessions-5dd1ec] The UI's build names its slot's API
- **WHEN** the stack of slot 2 is rendered through `bin/compose config`
- **THEN** the `ui` service's build argument `VITE_API_URL` is `http://127.0.0.1:11101` and the backend's `APP_URL` is `http://127.0.0.1:11100`

### Requirement: Every start rebuilds the stack's images
`bin/up` SHALL build the stack's images on every start, from the cache when nothing changed, so a build argument taken from the session (such as the UI's API origin) or a source edit made without `--watch` is never served stale.

#### Scenario: [dev-sessions-d71246] bin/up builds before it starts
- **WHEN** `bin/up` runs twice in the same worktree
- **THEN** each run starts the stack with `up -d --build`

### Requirement: bin/compose layers the build cache on request
`bin/compose` SHALL also layer `docker-compose.cache.yml`, which gives every built service a BuildKit GitHub Actions cache scoped to that service, only when `FACTORY_BUILD_CACHE=gha`.

#### Scenario: [dev-sessions-f7badf] The cache layer is added only on request
- **WHEN** `bin/compose config` runs with `FACTORY_BUILD_CACHE=gha`
- **THEN** the `backend` and `ui` services have `cache_from` and `cache_to` entries of `type=gha` with scopes `backend` and `ui`
- **AND** without the setting neither service has a `cache_from` or `cache_to`

### Requirement: An unknown build cache is refused
`bin/compose` SHALL exit 1 naming the variable and its one accepted value when `FACTORY_BUILD_CACHE` is set to anything other than `gha`.

#### Scenario: [dev-sessions-a3e5cb] A typo in the cache setting fails
- **WHEN** `bin/compose ps` runs with `FACTORY_BUILD_CACHE=gh`
- **THEN** it exits 1 and says `FACTORY_BUILD_CACHE` accepts only `gha`

### Requirement: bin/up refuses a wildcard bind host
`bin/up` SHALL exit 1 when the bind host, read as Compose reads it (one pair of quotes and a trailing comment dropped), is `0.0.0.0`, `::` or another spelling of them (all zeros, bracketed, IPv4-mapped) and `FACTORY_ALLOW_WILDCARD_BIND` is not `1`, before it claims a slot or writes the session file, with a message saying the stack would be published on every network interface and naming the override.

#### Scenario: [dev-sessions-08d768] An IPv4 wildcard is refused and nothing is claimed
- **WHEN** `bin/up` runs with `FACTORY_BIND_HOST=0.0.0.0` and no override
- **THEN** it exits 1, the error names every network interface and `FACTORY_ALLOW_WILDCARD_BIND=1`, and no slot is claimed and no session file is written

#### Scenario: [dev-sessions-699a23] An IPv6 wildcard from the machine env file is refused
- **WHEN** `~/.factory/env` sets `FACTORY_BIND_HOST=::` and nothing overrides it
- **THEN** `bin/up` exits 1 with the same message

#### Scenario: [dev-sessions-97b234] A quoted or respelled wildcard is refused
- **WHEN** the bind host is `"0.0.0.0"`, `0.0.0.0 # lan`, `::0`, `[::0]`, `0:0:0:0:0:0:0:0`, `::ffff:0.0.0.0` or `0`, from the environment or `~/.factory/env`, with no override
- **THEN** `bin/up` exits 1 as for `0.0.0.0` and claims nothing

#### Scenario: [dev-sessions-7e2a45] Another override value is not an override
- **WHEN** `bin/up` runs with `FACTORY_BIND_HOST=0.0.0.0` and `FACTORY_ALLOW_WILDCARD_BIND=yes`
- **THEN** it exits 1 as without an override

### Requirement: An explicit override allows a wildcard bind host
With `FACTORY_ALLOW_WILDCARD_BIND=1`, from the environment or `~/.factory/env`, `bin/up` SHALL start the stack on a wildcard bind host and print a warning naming it.

#### Scenario: [dev-sessions-0cd666] The override from the environment starts the stack with a warning
- **WHEN** `bin/up` runs with `FACTORY_BIND_HOST=0.0.0.0` and `FACTORY_ALLOW_WILDCARD_BIND=1` exported
- **THEN** the stack starts with ports published on `0.0.0.0` and a warning naming the wildcard is printed

#### Scenario: [dev-sessions-68d352] The override from the machine env file is read
- **WHEN** `~/.factory/env` sets `FACTORY_BIND_HOST=0.0.0.0` and `FACTORY_ALLOW_WILDCARD_BIND=1`
- **THEN** `bin/up` starts the stack

### Requirement: bin/up help names the wildcard override
`bin/up --help` SHALL name `FACTORY_ALLOW_WILDCARD_BIND` and say a wildcard bind host is refused without it.

#### Scenario: [dev-sessions-a7afd3] Help names the override
- **WHEN** `bin/up --help` runs
- **THEN** the output names `FACTORY_ALLOW_WILDCARD_BIND` and says `0.0.0.0` is refused without it

### Requirement: bin/doctor reports the OpenSpec download
`bin/doctor` SHALL print a line for the Node that `bin/openspec` needs: `ok` with Node 24 or newer, saying the first `bin/openspec` run downloads the pinned OpenSpec CLI and its version; `warn` with a fix naming where to install Node otherwise, a mark that alone never makes it fail.

#### Scenario: [dev-sessions-0ed22e] Node present notes the download
- **WHEN** `bin/doctor` runs with Node 24 on `PATH`
- **THEN** the Node line is `ok` and says the first `bin/openspec` run downloads OpenSpec at the version `bin/openspec` pins

#### Scenario: [dev-sessions-1bfb77] Missing or old Node only warns
- **WHEN** `bin/doctor` runs on an otherwise ready machine without `node`, or with Node 22
- **THEN** the Node line is `warn`, its fix names https://nodejs.org, and it exits 0

### Requirement: bin/stop waits for the stack to stop
`bin/stop` SHALL exit 0 only once no container of the worktree's stack runs, waiting up to `FACTORY_STOP_TIMEOUT` seconds (default 30) after Compose's stop.

#### Scenario: [dev-sessions-a29c95] A container that stops late is waited for
- **WHEN** a container of the stack still runs when Compose's stop returns and stops within the wait
- **THEN** `bin/stop` waits for it and exits 0, with no container of the stack running

### Requirement: bin/stop names a container that keeps running
`bin/stop` SHALL exit 1 and name the service and status of each container of the stack still running when its wait ends.

#### Scenario: [dev-sessions-e90f8e] A container that keeps running fails the stop
- **WHEN** a container of the stack still runs when the wait ends
- **THEN** `bin/stop` exits 1 and names that container's service and status
