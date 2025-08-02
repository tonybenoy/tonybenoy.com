// Full-page terminal specific code
document.addEventListener('DOMContentLoaded', () => {
    // Initialize fullpage terminal with existing WebTerminal class
    const terminal = new WebTerminal();
    
    // Override methods to use fullpage elements
    terminal.isFullPage = true;
    terminal.isMinimized = false;
    
    // Override addOutput method
    terminal.addOutput = function(text, type = 'info') {
        const output = document.getElementById('terminal-output-fullpage');
        const line = document.createElement('div');
        line.className = `terminal-line terminal-${type}`;
        line.textContent = text;
        output.appendChild(line);
    };
    
    // Override clearTerminal method
    terminal.clearTerminal = function() {
        document.getElementById('terminal-output-fullpage').innerHTML = '';
        return 'Terminal cleared.';
    };
    
    // Override executeCommand to use fullpage input
    const originalExecuteCommand = terminal.executeCommand.bind(terminal);
    terminal.executeCommand = function(commandLine) {
        originalExecuteCommand(commandLine);
        this.scrollToBottom();
    };
    
    // Override scrollToBottom for fullpage
    terminal.scrollToBottom = function() {
        const body = document.querySelector('.terminal-body-fullpage');
        body.scrollTop = body.scrollHeight;
    };
    
    // Set up input handling for fullpage
    const input = document.getElementById('terminal-input-fullpage');
    input.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') {
            terminal.executeCommand(input.value.trim());
            input.value = '';
            terminal.historyIndex = -1;
        } else if (e.key === 'ArrowUp') {
            e.preventDefault();
            terminal.navigateHistory('up', input);
        } else if (e.key === 'ArrowDown') {
            e.preventDefault();
            terminal.navigateHistory('down', input);
        }
    });
    
    // Override navigateHistory for fullpage
    terminal.navigateHistory = function(direction, inputElement = null) {
        const targetInput = inputElement || document.getElementById('terminal-input-fullpage');
        
        if (direction === 'up' && this.historyIndex < this.history.length - 1) {
            this.historyIndex++;
            targetInput.value = this.history[this.historyIndex];
        } else if (direction === 'down' && this.historyIndex > 0) {
            this.historyIndex--;
            targetInput.value = this.history[this.historyIndex];
        } else if (direction === 'down' && this.historyIndex === 0) {
            this.historyIndex = -1;
            targetInput.value = '';
        }
    };
    
    // Add welcome message
    terminal.addOutput('Welcome to Tony\'s Full-Page Terminal! Type "help" for available commands.', 'success');
    
    // Update current path
    const path = window.location.pathname;
    terminal.currentPath = path === '/' ? '~' : path;
    const prompt = document.querySelector('.terminal-prompt');
    if (prompt) {
        prompt.textContent = `tony@tonybenoy.com:${terminal.currentPath}$`;
    }
    
    // Focus input
    input.focus();
    
    // Store terminal instance globally
    window.fullpageTerminal = terminal;
});