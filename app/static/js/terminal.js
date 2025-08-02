class WebTerminal {
    constructor(isFullPage = false) {
        this.history = [];
        this.historyIndex = -1;
        this.currentPath = '/';
        this.isMinimized = false;
        this.isFullPage = isFullPage;
        this.isHidden = true; // Terminal starts completely hidden
        this.autoHidden = false;
        this.hideTimeout = null;
        this.commands = {
            help: () => this.showHelp(),
            ls: () => this.listPages(),
            cd: (args) => this.changePage(args[0]),
            pwd: () => this.currentLocation(),
            tree: () => this.showSiteTree(),
            whoami: () => this.showWhoAmI(),
            about: () => this.showAbout(),
            skills: () => this.showSkills(),
            experience: () => this.showExperience(),
            education: () => this.showEducation(),
            projects: () => this.showProjects(),
            contact: () => this.showContact(),
            date: () => this.showDate(),
            uptime: () => this.showUptime(),
            theme: () => this.toggleTheme(),
            clear: () => this.clearTerminal(),
            history: () => this.showHistory(),
            exit: () => this.closeTerminal(),
            fortune: () => this.showFortune(),
            joke: () => this.showJoke(),
            easter: () => this.showEaster()
        };

        this.pages = {
            '/': 'home',
            '/home': 'home',
            '/app': 'apps',
            '/apps': 'apps',
            '/timeline': 'timeline',
            '/contact': 'contact',
            '/terminal': 'terminal'
        };

        this.init();
    }

    init() {
        // Double-check we're not on the terminal page
        const currentPath = window.location.pathname;
        if (currentPath === '/terminal' || currentPath.includes('/terminal')) {
            return;
        }
        
        this.createTerminal();
        this.bindEvents();
        this.addOutput('Welcome to Tony\'s Interactive Terminal! Type "help" for available commands.', 'success');
        this.setCurrentPath();
        this.setupAutoHide();
    }

    setupAutoHide() {
        // Hide terminal when clicking anywhere outside of it (when expanded)
        document.addEventListener('click', (e) => {
            // Don't hide if clicking on the terminal itself or floating button
            const terminal = document.getElementById('web-terminal');
            const floatingBtn = document.getElementById('floating-terminal-btn');
            
            if (!terminal || this.isFullPage) return;
            
            // Check if click is outside terminal and floating button
            const isClickInsideTerminal = terminal.contains(e.target);
            const isClickOnFloatingBtn = floatingBtn && floatingBtn.contains(e.target);
            
            if (!isClickInsideTerminal && !isClickOnFloatingBtn && !this.isHidden) {
                this.autoHideTerminal();
            }
        });
    }

    createTerminal() {
        const terminal = document.createElement('div');
        terminal.className = 'terminal-container terminal-hidden';
        terminal.id = 'web-terminal';

        terminal.innerHTML = `
            <div class="terminal-header" id="terminal-header">
                <span class="terminal-title">tony@tonybenoy.com:~$</span>
                <div class="terminal-controls">
                    <button class="terminal-btn" id="terminal-maximize" title="Maximize">▲</button>
                    <button class="terminal-btn terminal-close" id="terminal-close" title="Close">×</button>
                </div>
            </div>
            <div class="terminal-body">
                <div class="terminal-output" id="terminal-output"></div>
                <div class="terminal-input-line">
                    <span class="terminal-prompt">tony@tonybenoy.com:${this.currentPath}$</span>
                    <input type="text" class="terminal-input" id="terminal-input" autocomplete="off" spellcheck="false">
                </div>
            </div>
        `;

        document.body.appendChild(terminal);
        
        // Add floating hide button
        if (!this.isFullPage) {
            this.createFloatingHideButton();
        }
    }

    bindEvents() {
        const header = document.getElementById('terminal-header');
        const maximizeBtn = document.getElementById('terminal-maximize');
        const closeBtn = document.getElementById('terminal-close');
        const input = document.getElementById('terminal-input');

        header.addEventListener('click', (e) => {
            if (e.target !== closeBtn && e.target !== maximizeBtn) {
                this.toggleTerminal();
            }
        });

        maximizeBtn.addEventListener('click', (e) => {
            e.stopPropagation();
            this.toggleTerminal();
        });

        closeBtn.addEventListener('click', (e) => {
            e.stopPropagation();
            this.closeTerminal();
        });

        input.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') {
                this.executeCommand(input.value.trim());
                input.value = '';
                this.historyIndex = -1;
            } else if (e.key === 'ArrowUp') {
                e.preventDefault();
                this.navigateHistory('up');
            } else if (e.key === 'ArrowDown') {
                e.preventDefault();
                this.navigateHistory('down');
            }
        });

        // Focus input when terminal is clicked
        document.getElementById('web-terminal').addEventListener('click', () => {
            if (!this.isMinimized) {
                input.focus();
            }
        });
    }

    toggleTerminal() {
        if (this.isHidden) {
            this.showTerminal();
        } else {
            this.autoHideTerminal();
        }
    }

    closeTerminal() {
        const terminal = document.getElementById('web-terminal');
        terminal.style.display = 'none';
    }
    
    autoHideTerminal() {
        if (!this.isHidden) {
            this.isHidden = true;
            this.isMinimized = false;
            this.autoHidden = true;
            const terminal = document.getElementById('web-terminal');
            
            if (terminal) {
                terminal.classList.add('terminal-hidden');
                terminal.classList.remove('terminal-minimized', 'terminal-auto-hidden');
            }
            
            // Show floating button
            this.showFloatingButton();
        }
    }
    
    createFloatingHideButton() {
        // Create floating button container
        const floatingContainer = document.createElement('div');
        floatingContainer.id = 'floating-terminal-container';
        floatingContainer.className = 'floating-terminal-container';
        
        // Create the button
        const floatingBtn = document.createElement('button');
        floatingBtn.id = 'floating-terminal-btn';
        floatingBtn.className = 'floating-terminal-button';
        floatingBtn.innerHTML = '📟';
        floatingBtn.title = 'Open Interactive Terminal';
        
        // Create hint bubble
        const hintBubble = document.createElement('div');
        hintBubble.id = 'terminal-hint-bubble';
        hintBubble.className = 'terminal-hint-bubble';
        hintBubble.innerHTML = 'Interactive Terminal Available!';
        
        floatingBtn.addEventListener('click', () => {
            this.showTerminal();
            this.hideHintBubble();
        });
        
        // Show hint bubble initially, then hide after a few seconds
        setTimeout(() => {
            this.showHintBubble();
            setTimeout(() => {
                this.hideHintBubble();
            }, 4000);
        }, 2000);
        
        floatingContainer.appendChild(floatingBtn);
        floatingContainer.appendChild(hintBubble);
        document.body.appendChild(floatingContainer);
    }
    
    showFloatingButton() {
        const floatingContainer = document.getElementById('floating-terminal-container');
        if (floatingContainer) {
            floatingContainer.style.display = 'block';
        }
    }
    
    hideFloatingButton() {
        const floatingContainer = document.getElementById('floating-terminal-container');
        if (floatingContainer) {
            floatingContainer.style.display = 'none';
        }
    }
    
    showHintBubble() {
        const hintBubble = document.getElementById('terminal-hint-bubble');
        if (hintBubble) {
            hintBubble.classList.add('show');
        }
    }
    
    hideHintBubble() {
        const hintBubble = document.getElementById('terminal-hint-bubble');
        if (hintBubble) {
            hintBubble.classList.remove('show');
        }
    }
    
    showTerminal() {
        this.isMinimized = false;
        this.isHidden = false;
        this.autoHidden = false;
        const terminal = document.getElementById('web-terminal');
        const maximizeBtn = document.getElementById('terminal-maximize');
        
        if (terminal) {
            terminal.classList.remove('terminal-hidden', 'terminal-minimized', 'terminal-auto-hidden');
        }
        if (maximizeBtn) {
            maximizeBtn.innerHTML = '▼';
            maximizeBtn.title = 'Minimize';
        }
        
        this.hideFloatingButton();
        const input = document.getElementById('terminal-input');
        if (input) {
            input.focus();
        }
    }

    executeCommand(commandLine) {
        if (!commandLine) return;

        this.history.unshift(commandLine);
        this.addOutput(`tony@tonybenoy.com:${this.currentPath}$ ${commandLine}`, 'command');

        const [command, ...args] = commandLine.split(' ');

        if (this.commands[command]) {
            this.commands[command](args);
        } else {
            this.addOutput(`Command not found: ${command}. Type "help" for available commands.`, 'error');
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
        this.updatePrompt();
    }

    updatePrompt() {
        const prompt = document.querySelector('.terminal-prompt');
        if (prompt) {
            prompt.textContent = `tony@tonybenoy.com:${this.currentPath}$`;
        }
    }

    clearTerminal() {
        document.getElementById('terminal-output').innerHTML = '';
        return 'Terminal cleared.';
    }

    showHelp() {
        const helpText = `Available commands:

Navigation:
  ls          - List available pages
  cd <page>   - Navigate to page (home, apps, timeline, contact)
  pwd         - Show current location
  tree        - Show site structure

Information:
  whoami      - About Tony
  about       - Biography
  skills      - Technical skills
  experience  - Work experience
  education   - Education background
  projects    - GitHub projects
  contact     - Contact information

System:
  date        - Current date/time
  uptime      - Site uptime
  theme       - Toggle dark/light mode
  clear       - Clear terminal
  history     - Command history
  exit        - Close terminal

Fun:
  fortune     - Random quote
  joke        - Programming joke
  easter      - Easter eggs

Type any command to get started!`;

        this.addOutput(helpText, 'info');
    }

    listPages() {
        const pages = `Available pages:
  home        - Main page
  apps        - Projects and applications
  timeline    - Professional timeline
  contact     - Get in touch
  terminal    - Full terminal interface

Use 'cd <page>' to navigate.`;
        this.addOutput(pages, 'info');
    }

    changePage(page) {
        if (!page) {
            this.addOutput('Usage: cd <page>', 'error');
            return;
        }

        const routes = {
            'home': '/',
            '~': '/',
            '/': '/',
            'apps': '/app',
            'app': '/app',
            'timeline': '/timeline',
            'contact': '/contact',
            'terminal': '/terminal'
        };

        if (routes[page]) {
            window.location.href = routes[page];
            this.addOutput(`Navigating to ${page}...`, 'success');
        } else {
            this.addOutput(`Page not found: ${page}. Use 'ls' to see available pages.`, 'error');
        }
    }

    currentLocation() {
        const page = this.pages[window.location.pathname] || 'unknown';
        this.addOutput(`Current location: ${window.location.pathname} (${page})`, 'info');
    }

    showSiteTree() {
        const tree = `tonybenoy.com/
├── home/           # Main landing page
├── apps/           # Projects and GitHub repos
├── timeline/       # Professional journey
└── contact/        # Get in touch`;
        this.addOutput(tree, 'info');
    }

    showWhoAmI() {
        this.addOutput('Tony Benoy - Software Engineer & Technology Leader', 'success');
    }

    showAbout() {
        const about = `Tony Benoy
Engineering leader and Software Engineer with expertise in Python, blockchain, and full-stack development.
Passionate about building scalable solutions and exploring emerging technologies.

Current focus: Web development, DevOps, and system architecture.`;
        this.addOutput(about, 'info');
    }

    showSkills() {
        const skills = `Technical Skills:
• Languages: Python, JavaScript, Go, Rust
• Frameworks: FastAPI, React, Django
• Databases: PostgreSQL, MongoDB, Redis
• DevOps: Docker, Kubernetes, CI/CD
• Cloud: AWS, GCP, Azure
• Blockchain: Ethereum, Solidity, Web3`;
        this.addOutput(skills, 'info');
    }

    showExperience() {
        const experience = `Professional Experience:
Check out the /timeline page for detailed work history and achievements.
Use 'cd timeline' to navigate there.`;
        this.addOutput(experience, 'info');
    }

    showEducation() {
        const education = `Education:
Visit the /timeline page for educational background and certifications.
Use 'cd timeline' to see more details.`;
        this.addOutput(education, 'info');
    }

    showProjects() {
        const projects = `GitHub Projects:
Visit the /apps page to see featured projects and GitHub repositories.
Use 'cd apps' to explore my work.`;
        this.addOutput(projects, 'info');
    }

    showContact() {
        const contact = `Contact Information:
Visit the /contact page for ways to get in touch.
Use 'cd contact' to see contact form and details.`;
        this.addOutput(contact, 'info');
    }

    showDate() {
        const now = new Date();
        this.addOutput(now.toString(), 'info');
    }

    showUptime() {
        const uptime = 'Site has been running smoothly! 🚀';
        this.addOutput(uptime, 'success');
    }

    toggleTheme() {
        const themeToggle = document.getElementById('theme-toggle');
        if (themeToggle) {
            themeToggle.click();
            this.addOutput('Theme toggled!', 'success');
        } else {
            this.addOutput('Theme toggle not available.', 'error');
        }
    }

    showHistory() {
        if (this.history.length === 0) {
            this.addOutput('No command history.', 'info');
            return;
        }

        this.addOutput('Command history:', 'info');
        this.history.slice(0, 10).forEach((cmd, index) => {
            this.addOutput(`  ${index + 1}. ${cmd}`, 'info');
        });
    }

    showFortune() {
        const fortunes = [
            "Code is like humor. When you have to explain it, it's bad.",
            "The best error message is the one that never shows up.",
            "Programming is 10% science, 20% ingenuity, and 70% getting the ingenuity to work with the science.",
            "Any fool can write code that a computer can understand. Good programmers write code that humans can understand.",
            "First, solve the problem. Then, write the code."
        ];

        const randomFortune = fortunes[Math.floor(Math.random() * fortunes.length)];
        this.addOutput(`💭 ${randomFortune}`, 'success');
    }

    showJoke() {
        const jokes = [
            "Why do programmers prefer dark mode? Because light attracts bugs!",
            "How many programmers does it take to change a light bulb? None, that's a hardware problem.",
            "Why do Java developers wear glasses? Because they can't C#!",
            "A SQL query goes into a bar, walks up to two tables and asks: 'Can I join you?'",
            "99 little bugs in the code, 99 little bugs. Take one down, patch it around, 117 little bugs in the code."
        ];

        const randomJoke = jokes[Math.floor(Math.random() * jokes.length)];
        this.addOutput(`😄 ${randomJoke}`, 'success');
    }

    showEaster() {
        const eastereggs = [
            "🥚 You found an easter egg! There might be more hidden around...",
            "🎮 Konami Code activated! ↑↑↓↓←→←→BA",
            "🐧 sudo make me a sandwich",
            "☕ Coffee.exe not found. Developer.exe has stopped working.",
            "🎵 Never gonna give you up, never gonna let you down... 🎵"
        ];

        const randomEgg = eastereggs[Math.floor(Math.random() * eastereggs.length)];
        this.addOutput(randomEgg, 'success');
    }
}

// Initialize terminal when page loads
document.addEventListener('DOMContentLoaded', () => {
    // Only create embedded terminal if not on full terminal page
    const currentPath = window.location.pathname;
    const isTerminalPage = currentPath === '/terminal' || currentPath.includes('/terminal');
    
    
    if (!isTerminalPage) {
        window.terminal = new WebTerminal();
        
        // Add CSS for animations and floating button
        const style = document.createElement('style');
        style.textContent = `
            .terminal-container {
                transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
            }
            
            .terminal-hidden {
                transform: translateY(100%);
                opacity: 0;
                pointer-events: none;
            }
            
            .floating-terminal-container {
                position: fixed;
                bottom: 20px;
                right: 20px;
                z-index: 10000;
                display: block;
            }
            
            .floating-terminal-button {
                background: #1a1a1a;
                color: #00ff00;
                border: 2px solid #00ff00;
                border-radius: 50%;
                width: 50px;
                height: 50px;
                font-size: 20px;
                cursor: pointer;
                box-shadow: 0 4px 12px rgba(0, 255, 0, 0.3);
                transition: all 0.3s ease;
                display: flex;
                align-items: center;
                justify-content: center;
                animation: pulse 2s infinite;
                position: relative;
            }
            
            .floating-terminal-button:hover {
                background: #00ff00;
                color: #1a1a1a;
                transform: scale(1.1);
                box-shadow: 0 6px 20px rgba(0, 255, 0, 0.5);
            }
            
            .terminal-hint-bubble {
                position: absolute;
                bottom: 60px;
                right: 0;
                background: #000;
                color: #00ff00;
                border: 1px solid #00ff00;
                border-radius: 8px;
                padding: 8px 12px;
                font-size: 12px;
                font-family: 'Courier New', monospace;
                white-space: nowrap;
                box-shadow: 0 2px 8px rgba(0, 255, 0, 0.3);
                opacity: 0;
                transform: translateY(10px);
                transition: all 0.3s ease;
                pointer-events: none;
                z-index: 10001;
            }
            
            .terminal-hint-bubble.show {
                opacity: 1;
                transform: translateY(0);
            }
            
            .terminal-hint-bubble::after {
                content: '';
                position: absolute;
                top: 100%;
                right: 20px;
                border: 6px solid transparent;
                border-top-color: #00ff00;
            }
            
            @keyframes pulse {
                0% { box-shadow: 0 4px 12px rgba(0, 255, 0, 0.3); }
                50% { box-shadow: 0 4px 20px rgba(0, 255, 0, 0.6); }
                100% { box-shadow: 0 4px 12px rgba(0, 255, 0, 0.3); }
            }
            
            @media (max-width: 768px) {
                .floating-terminal-container {
                    bottom: 15px;
                    right: 15px;
                }
                
                .floating-terminal-button {
                    width: 45px;
                    height: 45px;
                    font-size: 18px;
                }
                
                .terminal-hint-bubble {
                    font-size: 11px;
                    padding: 6px 10px;
                    bottom: 55px;
                }
            }
        `;
        document.head.appendChild(style);
    }
});
