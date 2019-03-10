//
//  Aspect.swift
//  Aspect
//
//  Created by Kris Liu on 2019/3/9.
//  Copyright © 2019 Syzygy. All rights reserved.
//

import Foundation

/// Custom aspect block type for hooking method
public typealias AspectBlock = @convention(block) (AspectObject) -> Void
