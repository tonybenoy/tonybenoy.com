class WebTerminal {
    constructor(isFullPage = false) {
        this.history = [];
        this.historyIndex = -1;
        this.currentPath = '~';
        this.isMinimized = false;
        this.isFullPage = isFullPage;
        this.isHidden = true;
        this.autoHidden = false;
        this.hideTimeout = null;
        this.startTime = Date.now();
        this.commands = {
            help: () => this.showHelp(),
            ls: (args) => this.listDir(args[0]),
            cd: (args) => this.changePage(args[0]),
            pwd: () => this.currentLocation(),
            tree: () => this.showSiteTree(),
            cat: (args) => this.catFile(args[0]),
            whoami: () => this.showWhoAmI(),
            id: () => this.showId(),
            hostname: () => this.addOutput('tonybenoy.com', 'info'),
            uname: (args) => this.showUname(args),
            neofetch: () => this.showNeofetch(),
            top: () => this.showTop(),
            df: () => this.showDf(),
            free: () => this.showFree(),
            ps: () => this.showPs(),
            ping: (args) => this.showPing(args[0]),
            curl: (args) => this.showCurl(args[0]),
            ssh: (args) => this.showSsh(args),
            sudo: (args) => this.showSudo(args),
            rm: (args) => this.showRm(args),
            vim: (args) => this.showVim(args),
            nano: () => this.addOutput("nano: command not found. Real developers use vim. Or at least that's what Tony tells himself.", 'error'),
            emacs: () => this.addOutput("emacs: let's not start this war on Tony's server.", 'error'),
            git: (args) => this.showGit(args),
            docker: (args) => this.showDocker(args),
            python: (args) => this.showPython(args),
            python3: (args) => this.showPython(args),
            node: () => this.addOutput("node: Tony has a complicated relationship with JavaScript. Please don't remind him.", 'error'),
            npm: () => this.addOutput("npm WARN deprecated tony's-patience@0.0.1: this package has been deprecated in favor of rust", 'info'),
            cargo: () => this.addOutput("cargo: Tony is still fighting the borrow checker. Check back later.", 'info'),
            man: (args) => this.showMan(args[0]),
            echo: (args) => this.addOutput(args.join(' '), 'info'),
            date: () => this.showDate(),
            uptime: () => this.showUptime(),
            w: () => this.showW(),
            theme: () => this.toggleTheme(),
            clear: () => this.clearTerminal(),
            history: () => this.showHistory(),
            exit: () => this.showExit(),
            logout: () => this.showExit(),
            fortune: () => this.showFortune(),
            sl: () => this.addOutput("🚂💨 Choo choo! You meant 'ls', didn't you?", 'success'),
            passwd: () => this.addOutput("passwd: Nice try. This session doesn't have write access to /etc/shadow.", 'error'),
            shutdown: () => this.addOutput("shutdown: Permission denied. Only Tony's deploy script can do that, and it's scared too.", 'error'),
            reboot: () => this.addOutput("reboot: The server politely declines. It just got comfortable.", 'error'),
            htop: () => this.showTop(),
            wget: (args) => this.addOutput(`wget: Tony's server doesn't download random files from strangers. Nothing personal.`, 'error'),
            apt: () => this.addOutput("apt: This server runs on vibes and Docker. No apt allowed.", 'error'),
            'apt-get': () => this.addOutput("apt-get: See above. Docker or nothing.", 'error'),
            pacman: () => this.addOutput("pacman: Tony maintained AUR packages for 7 years. He's earned the right to not use pacman on his server.", 'info'),
            yum: () => this.addOutput("yum: This isn't a RHEL box. Tony has standards.", 'error'),
            make: (args) => this.showMake(args),
            touch: (args) => this.addOutput(`touch: cannot create '${args[0] || 'file'}': Read-only file system. This is a portfolio, not a playground.`, 'error'),
            mkdir: (args) => this.addOutput(`mkdir: cannot create directory '${args[0] || 'dir'}': Read-only file system`, 'error'),
            chmod: () => this.addOutput("chmod: Nice try. Permissions stay exactly where Tony put them.", 'error'),
            chown: () => this.addOutput("chown: Everything here belongs to tony:tony. As it should.", 'error'),
            find: () => this.addOutput("find: Try 'ls' or 'tree' instead. This isn't a scavenger hunt. ...or is it? (click Tony's photo 7 times)", 'info'),
            grep: (args) => this.addOutput(`grep: searching for '${args[0] || 'meaning'}' in Tony's codebase... found 0 results. Have you tried Stack Overflow?`, 'info'),
            tail: () => this.addOutput("tail -f /var/log/tony.log: [INFO] Still writing code. [WARN] Needs more coffee. [ERROR] JavaScript.", 'info'),
            head: () => this.addOutput("head: Tony's head is full of ideas. Most of them involve Rust rewrites.", 'info'),
            jobs: () => this.addOutput("CTO @ Proffyhub  [running]\nFounder @ Sunyata [running]\nSleep             [suspended]", 'info'),
            fg: () => this.addOutput("fg: bringing 'Sleep' to foreground... just kidding, Tony doesn't sleep.", 'info'),
            bg: () => this.addOutput("bg: all of Tony's side projects are already running in the background.", 'info'),
            alias: () => this.addOutput("alias ll='ls -la'\nalias please='sudo'\nalias yolo='git push --force'\nalias sorry='git revert HEAD'", 'info'),
            which: (args) => this.addOutput(`/usr/local/bin/${args[0] || 'tony'}`, 'info'),
            whereis: (args) => this.addOutput(`${args[0] || 'tony'}: /home/tony /home/tony/projects /home/tony/.config/existential-dread`, 'info'),
            lscpu: () => this.addOutput("Architecture: x86_64 running on pure determination\nCPU(s): Enough to run this website\nModel name: Tony's Overworked Server\nBogoMIPS: Over 9000", 'info'),
            yes: () => this.addOutput("yes yes yes yes yes... ok that's enough. Tony's server has better things to do.", 'info'),
        };

        this.pages = {
            '/': 'home',
            '/home': 'home',
            '/app': 'apps',
            '/apps': 'apps',
            '/timeline': 'timeline',
            '/contact': 'contact',
            '/terminal': 'terminal',
            '/chat': 'chat',
            '/photography': 'photography'
        };

        this.init();
    }

    init() {
        const currentPath = window.location.pathname;
        if (currentPath === '/terminal' || currentPath.includes('/terminal')) {
            return;
        }
        this.createTerminal();
        this.bindEvents();
        this.setCurrentPath();
    }

    createTerminal() {
        // No embedded terminal — it lives only on /terminal now
    }

    bindEvents() {
        // No embedded terminal to bind
    }

    toggleTerminal() {}
    closeTerminal() {}
    autoHideTerminal() {}
    createFloatingHideButton() {}
    showFloatingButton() {}
    hideFloatingButton() {}
    showHintBubble() {}
    hideHintBubble() {}
    showTerminal() {}

    executeCommand(commandLine) {
        if (!commandLine) return;

        this.history.unshift(commandLine);
        this.addOutput(`tony@tonybenoy.com:${this.currentPath}$ ${commandLine}`, 'command');

        const parts = commandLine.match(/(?:[^\s"]+|"[^"]*")+/g) || [];
        const command = parts[0];
        const args = parts.slice(1).map(a => a.replace(/^"|"$/g, ''));

        if (this.commands[command]) {
            this.commands[command](args);
        } else {
            this.addOutput(`bash: ${command}: command not found`, 'error');
        }

        this.scrollToBottom();
    }

    addOutput(text, type = 'info') {
        const output = document.getElementById('terminal-output');
        const line = document.createElement('div');
        line.className = `terminal-line terminal-${type}`;
        line.textContent = text;
        output.appendChild(line);
    }

    scrollToBottom() {
        const body = document.querySelector('.terminal-body');
        body.scrollTop = body.scrollHeight;
    }

    navigateHistory(direction) {
        const input = document.getElementById('terminal-input');
        if (direction === 'up' && this.historyIndex < this.history.length - 1) {
            this.historyIndex++;
            input.value = this.history[this.historyIndex];
        } else if (direction === 'down' && this.historyIndex > 0) {
            this.historyIndex--;
            input.value = this.history[this.historyIndex];
        } else if (direction === 'down' && this.historyIndex === 0) {
            this.historyIndex = -1;
            input.value = '';
        }
    }

    setCurrentPath() {
        const path = window.location.pathname;
        this.currentPath = path === '/' ? '~' : path;
    }

    clearTerminal() {
        const output = document.getElementById('terminal-output') ||
                       document.getElementById('terminal-output-fullpage');
        if (output) output.innerHTML = '';
    }

    // === COMMANDS ===

    showHelp() {
        this.addOutput(`GNU Tony's Server 5.2.26 — Type commands like you own the place (you don't).

NAVIGATION
  ls [dir]        List directory contents
  cd <page>       Navigate to page
  pwd             Print working directory
  tree            Show site structure
  cat <file>      Read a file

RECONNAISSANCE
  whoami          Who are you on this server
  id              Your access level
  neofetch        System info (the cool way)
  uname -a        System info (the boring way)
  hostname        Server hostname
  uptime          How long Tony's been running
  w               Who's logged in
  jobs            Tony's current jobs

SYSTEM
  top / htop      Process viewer
  ps              Running processes
  df              Disk usage
  free            Memory usage
  lscpu           CPU info

NETWORK
  ping <host>     Ping a host
  curl <url>      Fetch a URL
  ssh <host>      SSH somewhere

DANGEROUS
  sudo <cmd>      Try to be root
  rm <file>       Delete something
  vim <file>      Enter vim (good luck leaving)
  chmod / chown   Change permissions

DEV TOOLS
  git <cmd>       Git commands
  docker <cmd>    Docker commands
  python          Start Python
  cargo / npm     Package managers
  make <target>   Build something

MISC
  echo <text>     Print text
  fortune         Random wisdom
  alias           Show aliases
  date            Current date
  clear           Clear screen
  history         Command history
  exit            Close session`, 'info');
    }

    listDir(dir) {
        if (dir === '-la' || dir === '-l' || dir === '-al' || dir === '-a') {
            this.addOutput(`total 42
drwxr-xr-x  8 tony tony 4096 Mar 15 22:00 .
drwxr-xr-x  3 root root 4096 Nov 12  2022 ..
-rw-------  1 tony tony 2847 Mar 15 21:58 .bash_history
-rw-r--r--  1 tony tony  220 Nov 12  2022 .bashrc
drwx------  4 tony tony 4096 Mar 15 20:00 .cache
drwxr-xr-x  8 tony tony 4096 Mar 15 22:00 .config
drwxr-xr-x  2 tony tony 4096 Jan  5 10:30 .ssh
-rw-r--r--  1 tony tony  807 Nov 12  2022 .profile
-rw-r--r--  1 tony tony  167 Mar 15 19:00 .zshrc
-rw-r--r--  1 tony tony   42 Jan  1  2024 README.md
drwxr-xr-x  6 tony tony 4096 Mar 14 18:00 projects/
drwxr-xr-x  4 tony tony 4096 Mar 10 12:00 websites/
-rwxr-xr-x  1 tony tony 1337 Feb 28 09:00 deploy.sh
-rw-r--r--  1 tony tony  512 Mar  1 14:00 todo.txt`, 'info');
        } else if (dir === 'projects' || dir === 'projects/') {
            this.addOutput(`sigyn/        treen/        cocapi/       tonybenoy.com/
sunyata/      dotfiles/     scripts/`, 'info');
        } else if (dir === '.ssh' || dir === '.ssh/') {
            this.addOutput(`authorized_keys  config  id_ed25519  id_ed25519.pub  known_hosts`, 'info');
        } else {
            this.addOutput(`home/     apps/     timeline/     photography/
terminal/ chat/     contact/`, 'info');
        }
    }

    changePage(page) {
        if (!page) {
            this.currentPath = '~';
            this.addOutput('', 'info');
            return;
        }
        if (page === '..') {
            this.currentPath = '~';
            this.addOutput('', 'info');
            return;
        }
        const routes = {
            'home': '/', '~': '/', '/': '/',
            'apps': '/app', 'app': '/app', 'projects': '/app',
            'timeline': '/timeline',
            'contact': '/contact',
            'terminal': '/terminal',
            'chat': '/chat',
            'photography': '/photography', 'photos': '/photography'
        };
        if (routes[page]) {
            this.addOutput(`Connecting to ${page}...`, 'success');
            setTimeout(() => { window.location.href = routes[page]; }, 500);
        } else {
            this.addOutput(`bash: cd: ${page}: No such file or directory`, 'error');
        }
    }

    catFile(file) {
        const files = {
            'README.md': `# Tony Benoy
CTO at Proffyhub | Founder at Sunyata | Based in Tallinn, Estonia

A "Jugaadu" pretentious noob who builds things for the web.
Python enthusiast, Rust curious, complicated relationship with JavaScript.

If you're reading this, you probably have SSH access to my server.
Or you found the terminal page on my website. Either way, hi.`,
            '.zshrc': `# Tony's zshrc — don't touch
export EDITOR=vim
export PATH=$HOME/.cargo/bin:$PATH
alias ll="ls -la"
alias please="sudo"
alias yolo="git push --force"
alias sorry="git revert HEAD"
alias deploy="./deploy.sh && echo 'prayer mode activated'"
# TODO: stop aliasing everything`,
            'todo.txt': `[x] Ship Proffy.ee
[x] Get MBA
[ ] Finish learning Rust (lol)
[ ] Update LinkedIn (it's been 2 years)
[ ] Sleep
[ ] Touch grass
[ ] Stop adding features to personal website at 2am`,
            '.bash_history': `vim deploy.sh
./deploy.sh
./deploy.sh --force
./deploy.sh --please-work
sudo systemctl restart nginx
sudo systemctl restart nginx
sudo systemctl restart nginx
git push --force
git revert HEAD
echo "I should have been a farmer"`,
            'deploy.sh': `#!/bin/bash
# Tony's deploy script — handle with care
echo "Deploying tonybenoy.com..."
docker-compose pull
docker-compose up -d
echo "Clearing nginx cache..."
docker exec nginx nginx -s reload
echo "Deployed! Probably. Check the logs."
# If you're reading this, the deploy worked. Hopefully.`,
            '.profile': `# ~/.profile: executed by the command interpreter for login shells.
# Tony Benoy — CTO by day, terminal cosplayer by night.
echo "Welcome back, Tony. The server missed you."
echo "$(fortune -s 2>/dev/null || echo 'No fortune today. Make your own.')"`,
        };
        if (!file) {
            this.addOutput('cat: missing operand. Try: cat README.md', 'error');
        } else if (files[file]) {
            this.addOutput(files[file], 'info');
        } else {
            this.addOutput(`cat: ${file}: No such file or directory`, 'error');
        }
    }

    currentLocation() {
        this.addOutput(`/home/tony/${this.currentPath === '~' ? '' : this.currentPath}`, 'info');
    }

    showSiteTree() {
        this.addOutput(`/home/tony/tonybenoy.com/
├── app/
│   ├── routes/
│   │   ├── home.py        # Home, timeline, terminal, chat
│   │   ├── apps.py        # Projects page
│   │   └── photography.py # Bird photos
│   ├── templates/         # Jinja2 templates
│   ├── static/
│   │   ├── css/           # Stylesheets
│   │   ├── js/            # This terminal, among other things
│   │   └── img/           # Tony's face and logos
│   └── main.py            # FastAPI entry point
├── docker/
│   ├── Dockerfile
│   └── nginx.conf
├── docker-compose.yml
├── pyproject.toml
└── README.md              # You are here (spiritually)`, 'info');
    }

    showWhoAmI() {
        this.addOutput('visitor — you have read-only guest access to tony\'s server.', 'info');
        this.addOutput('To get root, try "sudo" and see what happens.', 'info');
    }

    showId() {
        this.addOutput('uid=1001(visitor) gid=1001(guests) groups=1001(guests),27(read-only),100(curious-people)', 'info');
    }

    showUname(args) {
        if (args.includes('-a') || args.length === 0) {
            this.addOutput('Linux tonybenoy.com 6.1.0-tony x86_64 GNU/Linux (running on vibes and caffeine)', 'info');
        } else if (args.includes('-r')) {
            this.addOutput('6.1.0-tony', 'info');
        } else {
            this.addOutput('Linux', 'info');
        }
    }

    showNeofetch() {
        this.addOutput(`        .--.         tony@tonybenoy.com
       |o_o |        ------------------
       |:_/ |        OS: TonyOS 2024.1 (Tallinn Edition)
      //   \\ \\       Host: tonybenoy.com
     (|     | )      Kernel: 6.1.0-tony
    /'\\_   _/\`\\      Uptime: since 2017 (it's been a ride)
    \\___)=(___/      Shell: zsh 5.9
                     Terminal: this one, obviously
  Tony Benoy         CPU: Caffeine-Powered ARM
  CTO & Builder      Memory: Full of side project ideas
                     Disk: 73% (mostly node_modules)
                     Languages: Python, TypeScript, Rust
                     Current: CTO @ Proffyhub
                     Hobby: Chasing kingfishers with a camera`, 'success');
    }

    showTop() {
        this.addOutput(`top - ${new Date().toTimeString().slice(0,8)} up 2547 days, load average: 0.42, 0.38, 0.35

  PID USER      %CPU %MEM    COMMAND
    1 tony       0.3  1.2    fastapi (tonybenoy.com)
    2 tony       0.1  0.8    nginx (reverse proxy)
    3 tony       0.0  0.4    certbot (ssl renewal)
    7 tony      12.4  8.3    proffy.ee (the actual job)
   13 tony       4.2  3.1    sigyn (rust side project)
   21 tony       2.1  1.5    treening (fitness app)
   34 tony      87.3 42.0    existential-dread
   42 tony       0.0  0.0    sleep (zombie process)`, 'info');
    }

    showDf() {
        this.addOutput(`Filesystem      Size  Used Avail Use% Mounted on
/dev/ambition   500G  365G  135G  73% /
/dev/ideas      ∞     ∞     0     100% /home/tony/projects
/dev/patience    8G    7G    1G   88% /home/tony/javascript
/dev/coffee     16G    0G   16G    0% /home/tony/.energy (refilling...)
tmpfs           n/a   n/a   n/a   n/a /home/tony/free-time (not mounted)`, 'info');
    }

    showFree() {
        this.addOutput(`              total        used        free      shared  buff/cache   available
Mem:       16384000    12582912     1048576     524288     2752512     3801088
Swap:       8192000     4194304     3997696

Note: 76% of memory is used by Tony's browser tabs. He promises to close them "later".`, 'info');
    }

    showPs() {
        this.addOutput(`  PID TTY          TIME CMD
    1 pts/0    00:00:00 bash
   42 pts/0    00:00:00 you (reading this)
  137 pts/0    23:59:59 tony-overthinking-architecture
  404 pts/0    00:00:00 free-time (not found)`, 'info');
    }

    showPing(host) {
        if (!host) {
            this.addOutput('ping: usage error: Destination address required', 'error');
            return;
        }
        if (host === 'google.com') {
            this.addOutput(`PING google.com (142.250.80.46): 56 data bytes
64 bytes from 142.250.80.46: icmp_seq=0 ttl=118 time=1.337 ms
64 bytes from 142.250.80.46: icmp_seq=1 ttl=118 time=1.042 ms
--- google.com ping statistics ---
2 packets transmitted, 2 received, 0% packet loss
Tony's internet is fine. The problem is always DNS.`, 'info');
        } else if (host === 'localhost' || host === '127.0.0.1') {
            this.addOutput(`PING localhost: 64 bytes, icmp_seq=0 time=0.042ms
Yes, the server is talking to itself. We all do sometimes.`, 'info');
        } else {
            this.addOutput(`PING ${host}: 64 bytes, icmp_seq=0 time=42.0ms
${host} is alive. Unlike Tony's sleep schedule.`, 'info');
        }
    }

    showCurl(url) {
        if (!url) {
            this.addOutput('curl: try \'curl --help\' for more information', 'error');
            return;
        }
        if (url === 'tonybenoy.com' || url === 'https://tonybenoy.com') {
            this.addOutput(`HTTP/1.1 200 OK
Server: nginx (Tony's personal instance)
Content-Type: text/html; charset=utf-8
X-Powered-By: FastAPI, caffeine, and imposter syndrome
X-Tony-Status: Currently alive and building things

<!DOCTYPE html>
<html>... you're already here. Look around!</html>`, 'info');
        } else {
            this.addOutput(`curl: (7) Tony's server doesn't make outbound requests for strangers. Security policy.`, 'error');
        }
    }

    showSsh(args) {
        const target = args.join(' ');
        if (!target) {
            this.addOutput('usage: ssh user@host', 'error');
        } else {
            this.addOutput(`ssh: connect to host ${target}: Connection refused`, 'error');
            this.addOutput("You're already on Tony's server. How much deeper do you want to go?", 'info');
        }
    }

    showSudo(args) {
        const cmd = args.join(' ');
        if (!cmd) {
            this.addOutput('usage: sudo <command>', 'error');
            return;
        }
        if (cmd === 'make me a sandwich') {
            this.addOutput('Okay.', 'success');
            return;
        }
        if (cmd.includes('rm -rf /')) {
            this.addOutput(`[sudo] password for visitor: `, 'info');
            setTimeout(() => {
                this.addOutput('Nice try. Incident logged. Tony has been notified.', 'error');
                this.addOutput('Just kidding. But seriously, don\'t.', 'info');
            }, 800);
            return;
        }
        this.addOutput(`[sudo] password for visitor: `, 'info');
        setTimeout(() => {
            this.addOutput('visitor is not in the sudoers file. This incident will be reported.', 'error');
            this.addOutput('(Not really. Tony doesn\'t check those logs. But still.)', 'info');
        }, 600);
    }

    showRm(args) {
        const target = args.join(' ');
        if (target.includes('-rf /') || target.includes('-rf /*')) {
            this.addOutput("rm: nice try. The server has self-preservation instincts.", 'error');
        } else if (target.includes('-rf node_modules')) {
            this.addOutput("rm: removed 847,293 files. Wait, they're back. npm install is running again.", 'info');
        } else if (target) {
            this.addOutput(`rm: cannot remove '${args[args.length-1]}': Operation not permitted (read-only guest session)`, 'error');
        } else {
            this.addOutput('rm: missing operand', 'error');
        }
    }

    showVim(args) {
        const file = args[0] || '';
        this.addOutput(`Opening ${file || 'untitled'}...`, 'info');
        setTimeout(() => {
            this.addOutput("Just kidding. This is a web terminal, not actual vim.", 'info');
            this.addOutput("But let's be honest — you wouldn't know how to exit anyway.", 'info');
            this.addOutput("(If you do: :wq and you know it.)", 'info');
        }, 500);
    }

    showGit(args) {
        const sub = args[0];
        if (!sub) {
            this.addOutput("usage: git <command>. Try: git status, git log, git blame", 'error');
            return;
        }
        const gitCmds = {
            'status': `On branch main
Your branch is up to date with 'origin/main'.

Changes not staged for commit:
  modified:   todo.txt (Tony added more items again)
  modified:   deploy.sh (3am "improvements")

Untracked files:
  another-side-project/
  this-will-definitely-be-finished/`,
            'log': `commit a1b2c3d (HEAD -> main, origin/main)
Author: Tony Benoy <me@tonybenoy.com>
Date:   ${new Date().toDateString()}

    fix: actually fix the thing I said I fixed yesterday

commit e4f5g6h
Author: Tony Benoy <me@tonybenoy.com>
Date:   yesterday

    feat: add AI chat because every website needs AI now

commit i7j8k9l
Author: Tony Benoy <me@tonybenoy.com>
Date:   last week

    refactor: rewrite CSS for the 4th time this month`,
            'blame': `Tony Benoy (100%)  — it's his personal website. Who else?`,
            'push': `Everything up-to-date. (Tony wishes his life was this organized.)`,
            'pull': `Already up to date. Unlike Tony's LinkedIn.`,
            'stash': `Saved working directory. Tony stashes his emotions the same way.`,
            'diff': `+ added more features nobody asked for
- removed sleep from schedule
~ changed mind about JavaScript (again)`,
        };
        this.addOutput(gitCmds[sub] || `git: '${sub}' is not a git command. See 'git --help'.`, sub === 'blame' || sub === 'push' || sub === 'pull' || sub === 'stash' ? 'info' : 'info');
    }

    showDocker(args) {
        const sub = args[0];
        if (sub === 'ps') {
            this.addOutput(`CONTAINER ID   IMAGE              STATUS          NAMES
a1b2c3d4e5f6   tonybenoy/web      Up 47 days      website
f6e5d4c3b2a1   nginx:alpine       Up 47 days      nginx-proxy
1234567890ab   certbot            Exited (0)      ssl-renew
deadbeef0000   postgres:16        Up 47 days      db (don't touch)`, 'info');
        } else if (sub === 'stop') {
            this.addOutput("docker: Error response: you can't stop Tony's containers from a guest terminal. That's chaos.", 'error');
        } else if (sub === 'rm') {
            this.addOutput("docker: Error response: deleting containers requires sudo and a good reason. You have neither.", 'error');
        } else {
            this.addOutput(`docker: '${sub || '???'}' — try 'docker ps' to see what's running.`, 'info');
        }
    }

    showPython(args) {
        if (args[0] === '-c') {
            const code = args.slice(1).join(' ');
            if (code.includes('import this')) {
                this.addOutput("The Zen of Python, by Tim Peters\n\nBeautiful is better than ugly.\nExplicit is better than implicit.\nSimple is better than complex.\n...Tony tries to follow these. Results vary.", 'info');
            } else if (code.includes('print')) {
                this.addOutput("Hello from Tony's server! Python " + "3.12" + " btw.", 'info');
            } else {
                this.addOutput("Python 3.12.0 — Tony's language of choice (don't tell Rust)", 'info');
            }
        } else {
            this.addOutput(`Python 3.12.0 (tony-build, compiled with love)
Type "exit()" to leave. But why would you?
>>> import tony
>>> tony.status()
'Building things in Tallinn. Send coffee.'
>>> tony.skills()
['Python', 'TypeScript', 'Rust (learning)', 'JavaScript (it\'s complicated)']
>>> exit()`, 'info');
        }
    }

    showMake(args) {
        const target = args[0];
        if (!target) {
            this.addOutput("make: *** No targets specified. Try: make help, make coffee, make money", 'error');
        } else if (target === 'coffee') {
            this.addOutput("Brewing... ☕ Done. Tony's productivity increased by 200%.", 'success');
        } else if (target === 'money') {
            this.addOutput("make: *** No rule to make target 'money'. If you figure it out, let Tony know.", 'error');
        } else if (target === 'love') {
            this.addOutput("make: *** Target 'love' requires dependency 'free-time', which is not installed.", 'error');
        } else if (target === 'help') {
            this.addOutput("Available targets: coffee, love, money, sense\n(Only 'coffee' actually works.)", 'info');
        } else if (target === 'sense') {
            this.addOutput("make: *** 'sense' is deprecated. Use 'vibes' instead.", 'error');
        } else {
            this.addOutput(`make: *** No rule to make target '${target}'. Stop.`, 'error');
        }
    }

    showMan(cmd) {
        if (!cmd) {
            this.addOutput('What manual page do you want?\nFor example, try \'man tony\'', 'error');
        } else if (cmd === 'tony') {
            this.addOutput(`TONY(1)                    User Commands                    TONY(1)

NAME
       tony - CTO, builder, jugaadu

SYNOPSIS
       tony [--coffee] [--code] [--build] [--ship]

DESCRIPTION
       Tony Benoy is a CTO and full-stack engineer based in Tallinn,
       Estonia. He builds things for the web, occasionally photographs
       birds, and maintains an unreasonable number of side projects.

       Currently serving as CTO at Proffyhub and running Sunyata OÜ.
       Previously broke things at Merkle Science and Redcarpetup (YC).
       Has an MBA from Estonian Business School, which he uses primarily
       to justify calling meetings "strategic alignment sessions."

OPTIONS
       --coffee    Required flag. Tony does not operate without it.
       --sleep     Deprecated. Use --coffee instead.
       --rust      Experimental. May cause borrow checker frustration.

BUGS
       Known issue: occasionally starts new side projects before
       finishing existing ones. No fix planned.

SEE ALSO
       tonybenoy.com, github.com/tonybenoy, sigyn.org, treen.ing`, 'info');
        } else {
            this.addOutput(`No manual entry for ${cmd}. Tony only documented himself.`, 'error');
        }
    }

    showDate() {
        this.addOutput(new Date().toString(), 'info');
    }

    showUptime() {
        const now = Date.now();
        const sessionSec = Math.floor((now - this.startTime) / 1000);
        const min = Math.floor(sessionSec / 60);
        const sec = sessionSec % 60;
        this.addOutput(` ${new Date().toTimeString().slice(0,8)} up 2547 days (since Tony learned to code), ${min}m ${sec}s this session, 1 user, load average: too much`, 'info');
    }

    showW() {
        this.addOutput(`${new Date().toTimeString().slice(0,8)} up 2547 days, 1 user, load average: 0.42 0.38 0.35
USER     TTY      FROM             IDLE   WHAT
visitor  pts/0    your-browser     0.00s  exploring tony's server
tony     pts/1    tallinn          2d     probably coding something`, 'info');
    }

    toggleTheme() {
        const themeToggle = document.getElementById('theme-toggle');
        if (themeToggle) {
            themeToggle.click();
            this.addOutput('Theme toggled. The terminal stays dark though. It has standards.', 'success');
        }
    }

    showHistory() {
        if (this.history.length === 0) {
            this.addOutput('No command history yet. Start typing!', 'info');
            return;
        }
        this.history.slice(0, 15).forEach((cmd, index) => {
            this.addOutput(`  ${String(index + 1).padStart(4)}  ${cmd}`, 'info');
        });
    }

    showExit() {
        this.addOutput('logout', 'info');
        this.addOutput('Connection to tonybenoy.com closed.', 'info');
        setTimeout(() => {
            this.addOutput('...just kidding. You can\'t leave. This is a web page.', 'info');
            this.addOutput('But you can "cd home" to go back to the homepage.', 'info');
        }, 1000);
    }

    showFortune() {
        const fortunes = [
            "Tony's server fortune: You will mass-rename variables tomorrow. Your tests will not thank you.",
            "Tony's server fortune: A 'quick refactor' will take exactly 3 days. Plan accordingly.",
            "Tony's server fortune: The bug is not where you're looking. It never is.",
            "Tony's server fortune: You will discover that the previous developer was also you.",
            "Tony's server fortune: Today is a good day to finally close those 47 browser tabs. (You won't.)",
            "Tony's server fortune: The documentation was accurate once. In 2019.",
            "Tony's server fortune: Your PR will be approved. After 7 rounds of review.",
            "Tony's server fortune: A wise developer once said: 'It works on my machine.' And deployed anyway.",
            "Tony's server fortune: The real treasure was the merge conflicts we resolved along the way.",
            "Tony's server fortune: sudo won't help you here. Nothing will. Ship it anyway.",
        ];
        this.addOutput(fortunes[Math.floor(Math.random() * fortunes.length)], 'success');
    }
}

// Only initialize if NOT on the terminal page
// (the fullpage terminal has its own initialization)
document.addEventListener('DOMContentLoaded', () => {
    const currentPath = window.location.pathname;
    const isTerminalPage = currentPath === '/terminal' || currentPath.includes('/terminal');
    if (!isTerminalPage) {
        window.terminal = new WebTerminal();
    }
});
