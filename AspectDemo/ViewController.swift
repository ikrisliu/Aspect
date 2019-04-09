//
//  ViewController.swift
//  AspectDemo
//
//  Created by Kris Liu on 2019/3/12.
//  Copyright © 2019 Syzygy. All rights reserved.
//

import UIKit
import Aspect

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onTap)))
    }
    
    @objc private func onTap() {
        let detailVC = DetailViewController()
        navigationController?.pushViewController(detailVC, animated: true)
    }
}


class DetailViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .lightGray
        
        DispatchQueue.global().async {
            self.hook(#selector(self.testAfter), position: .after, usingBlock: { _ in
                DispatchQueue.global().async {
                    print("Hook after position")
                }
            } as AspectBlock)
            
            self.hook(#selector(self.testBefore), position: .before, usingBlock: { _ in
                print("Hook before position")
            } as AspectBlock)
        }
        
        DetailViewController.hook(#selector(testInstead), position: .instead, usingBlock: { _ in
            print("Hook instead position")
        } as AspectBlock)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.testAfter()
            self.testBefore()
            self.testInstead()
        }
    }
    
    @objc dynamic private func testAfter() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            print("testAfter executed")
        }
    }
    
    @objc dynamic private func testBefore() {
        DispatchQueue.global().async {
            print("testBefore executed")
        }
    }
    
    @objc dynamic private func testInstead() {
        DispatchQueue.global().async {
            print("This message shouldn't be printed")
        }
    }
    
    deinit {
        print("detail vc free")
    }
}
