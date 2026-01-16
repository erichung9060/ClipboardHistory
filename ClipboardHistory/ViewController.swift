import Cocoa

class ViewController: NSViewController {
    @IBOutlet weak var RememberingNumberTextField: NSTextField!
    @IBOutlet weak var DisplayingNumberTextField: NSTextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let appDelegate = NSApp.delegate as? AppDelegate {
            RememberingNumberTextField.stringValue = "\(appDelegate.rememberingNumber)"
            DisplayingNumberTextField.stringValue = "\(appDelegate.displayingNumber)"
        }
    }

    override var representedObject: Any? {
        didSet {
        }
    }

    
    @IBAction func UpdateRememberingNumber(_ sender: Any) {
        if let number = Int(RememberingNumberTextField.stringValue.replacingOccurrences(of: ",", with: "")) {
            if let appDelegate = NSApp.delegate as? AppDelegate {
                let originalNumber = appDelegate.rememberingNumber
                appDelegate.rememberingNumber = number
                if number < originalNumber {
                    appDelegate.updateRememberingNumber()
                }
            }
        }
    }
    
    @IBAction func UpdateDisplayingNumber(_ sender: Any) {
        if let number = Int(DisplayingNumberTextField.stringValue.replacingOccurrences(of: ",", with: "")){
            if let appDelegate = NSApp.delegate as? AppDelegate {
                appDelegate.displayingNumber = number
            }
        }
    }
}
