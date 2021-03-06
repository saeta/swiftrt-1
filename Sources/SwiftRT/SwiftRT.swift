//******************************************************************************
// Copyright 2020 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

// A module that re-exports the complete SwiftRT public API.
@_exported import SwiftRTCore
@_exported import SwiftRTLayers

// Copied from SwiftRTCore/operators/Infix.swift
// Comparative
infix operator .&& : LogicalConjunctionPrecedence
infix operator .|| : LogicalConjunctionPrecedence
infix operator .== : ComparisonPrecedence
infix operator .!= : ComparisonPrecedence
infix operator .> : ComparisonPrecedence
infix operator .>= : ComparisonPrecedence
infix operator .< : ComparisonPrecedence
infix operator .<= : ComparisonPrecedence

// advanced ranges
infix operator ..+: RangeFormationPrecedence
infix operator ..<-: RangeFormationPrecedence
infix operator ...-: RangeFormationPrecedence
prefix operator ..<-
prefix operator ...-

precedencegroup StridedRangeFormationPrecedence {
    associativity: left
    higherThan: CastingPrecedence
    lowerThan: RangeFormationPrecedence
}

infix operator ..: StridedRangeFormationPrecedence
