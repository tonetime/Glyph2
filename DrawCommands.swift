import UIKit

protocol Canvas {
    var context: CGContext {get}
    func reset()
}

protocol DrawCommand {
    func execute(_ canvas: Canvas)
}

protocol DrawCommandReceiver {
    func executeCommands(_ commands: [DrawCommand])
}
