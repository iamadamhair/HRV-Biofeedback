//
//  SettingsViewController.swift
//  HR Breathing
//
//  Created by Adam Hair on 7/11/17.
//  Copyright © 2017 Adam Hair. All rights reserved.
//

import Foundation
import UIKit

class SettingsViewController : UIViewController, UITextFieldDelegate {

    // Keys to save/retrieve defaults
    let rrIntervalKey = "rrIntervalSegmentIndex"
    let hrvFunctionKey = "hrvFunctionSegmentIndex"
    let logDataKey = "logDataSwitchBool"
    let secondsInKey = "secondsBreatheIn"
    let secondsOutKey = "secondsBreatheOut"
    
    // Initial parameters for some of the defaults
    let defaultSecondsIn = 4
    let defaultSecondsOut = 6
    
    let defaults = UserDefaults.standard
    
    @IBOutlet weak var rrIntervalSegmentedControlOutlet: UISegmentedControl!
    @IBOutlet weak var hrvFormulaSegmentedControlOutlet: UISegmentedControl!
    @IBOutlet weak var logDataSwitchOutlet: UISwitch!
    @IBOutlet weak var secondsOutStepperOutlet: UIStepper!
    @IBOutlet weak var secondsInStepperOutlet: UIStepper!
    @IBOutlet weak var secondsOutLabelOutlet: UILabel!
    @IBOutlet weak var secondsInLabelOutlet: UILabel!
    
    @IBAction func rrIntervalSegmentedControlAction(_ sender: Any) {
        defaults.set(rrIntervalSegmentedControlOutlet.selectedSegmentIndex, forKey: rrIntervalKey)
        defaults.synchronize()
    }
    
    @IBAction func hrvFunctionSegmentedControlAction(_ sender: Any) {
        defaults.set(hrvFormulaSegmentedControlOutlet.selectedSegmentIndex, forKey: hrvFunctionKey)
        defaults.synchronize()
    }
    
    @IBAction func logDataSwitchAction(_ sender: Any) {
        defaults.set(logDataSwitchOutlet.isOn, forKey: logDataKey)
        defaults.synchronize()
        NSLog("Log default changed");
    }
    
    @IBAction func secondsInStepperAction(_ sender: Any) {
        defaults.set(secondsInStepperOutlet.value, forKey: secondsInKey)
        defaults.synchronize()
        secondsInLabelOutlet.text = defaults.double(forKey: secondsInKey).description + " Seconds In"
    }
    
    @IBAction func secondsOutStepperAction(_ sender: Any) {
        defaults.set(secondsOutStepperOutlet.value, forKey: secondsOutKey)
        defaults.synchronize()
        secondsOutLabelOutlet.text = defaults.double(forKey: secondsOutKey).description + " Seconds Out"
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if !defaultSet() {
            defaults.set(rrIntervalSegmentedControlOutlet.selectedSegmentIndex, forKey: rrIntervalKey)
            defaults.set(hrvFormulaSegmentedControlOutlet.selectedSegmentIndex, forKey: hrvFunctionKey)
            defaults.set(logDataSwitchOutlet.isOn, forKey: logDataKey)
            defaults.set(defaultSecondsIn, forKey: secondsInKey)
            defaults.set(defaultSecondsOut, forKey: secondsOutKey)
            defaults.synchronize()
        } else {
            rrIntervalSegmentedControlOutlet.selectedSegmentIndex = defaults.integer(forKey: rrIntervalKey)
            hrvFormulaSegmentedControlOutlet.selectedSegmentIndex = defaults.integer(forKey: hrvFunctionKey)
            logDataSwitchOutlet.setOn(defaults.bool(forKey: logDataKey), animated: false)
        }
        
        secondsInStepperOutlet.value = defaults.double(forKey: secondsInKey)
        secondsOutStepperOutlet.value = defaults.double(forKey: secondsOutKey)

        secondsInLabelOutlet.text = defaults.double(forKey: secondsInKey).description + " Seconds In"
        secondsOutLabelOutlet.text = defaults.double(forKey: secondsOutKey).description + " Seconds Out"
    }
    
    func defaultSet() -> Bool {
        if(defaults.object(forKey: rrIntervalKey) != nil) {
            return true
        } else {
            return false
        }
    }
}
