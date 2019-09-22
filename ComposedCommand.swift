

struct ComposedCommand : DrawCommand {
    init(commands: [DrawCommand]) {
        self.commands = commands;
    }
    
    // MARK: DrawCommand
    
    func execute(_ canvas: Canvas) {
        self.commands.map { $0.execute(canvas) }
    }
    
    mutating func addCommand(_ command: DrawCommand) {
        self.commands.append(command)
    }
    
    fileprivate var commands: [DrawCommand]
}
