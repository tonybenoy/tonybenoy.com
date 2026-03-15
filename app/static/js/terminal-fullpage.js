// Full-page terminal specific code
document.addEventListener('DOMContentLoaded', () => {
    const terminal = new WebTerminal();

    terminal.isFullPage = true;
    terminal.isMinimized = false;

    // Override addOutput to use fullpage elements
    terminal.addOutput = function(text, type = 'info') {
        const output = document.getElementById('terminal-output-fullpage');
        const line = document.createElement('div');
        line.className = `terminal-line terminal-${type}`;
        line.textContent = text;
        output.appendChild(line);
    };

    terminal.clearTerminal = function() {
        document.getElementById('terminal-output-fullpage').innerHTML = '';
    };

    const originalExecuteCommand = terminal.executeCommand.bind(terminal);
    terminal.executeCommand = function(commandLine) {
        originalExecuteCommand(commandLine);
        this.scrollToBottom();
    };

    terminal.scrollToBottom = function() {
        const body = document.querySelector('.terminal-body-fullpage');
        body.scrollTop = body.scrollHeight;
    };

    // Input handling
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
        } else if (e.key === 'Tab') {
            e.preventDefault();
            // Simple tab completion
            const val = input.value.trim();
            const cmds = Object.keys(terminal.commands);
            const matches = cmds.filter(c => c.startsWith(val));
            if (matches.length === 1) {
                input.value = matches[0] + ' ';
            } else if (matches.length > 1) {
                terminal.addOutput(matches.join('  '), 'info');
                terminal.scrollToBottom();
            }
        }
    });

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

    // SSH-style welcome banner
    terminal.addOutput(`Last login: ${new Date().toDateString()} from your-browser`, 'info');
    terminal.addOutput('', 'info');
    terminal.addOutput('Welcome to Tony\'s server (tonybenoy.com)', 'success');
    terminal.addOutput('  OS:     TonyOS 2024.1 / Tallinn Edition', 'info');
    terminal.addOutput('  Status: All systems operational', 'info');
    terminal.addOutput('  Access: Read-only guest session', 'info');
    terminal.addOutput('', 'info');
    terminal.addOutput('Type "help" for commands, "man tony" for the full manual,', 'info');
    terminal.addOutput('or "neofetch" if you just want the vibes.', 'info');
    terminal.addOutput('', 'info');

    terminal.currentPath = '~';
    input.focus();

    window.fullpageTerminal = terminal;
});
