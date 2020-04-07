//******************************************************************************
// Copyright 2019 Google LLC
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
import Numerics

//==============================================================================
// assert messages
public let _messageTensorExtentsMismatch = "tensor shape mismatch"

//==============================================================================
/// all(x:along:)
/// Returns `true` if all values are equal to `true` along the specified
/// axes. Otherwise returns `false`. The result extent along the specified
/// axes will be 1. Rank is not reduced.
/// - Parameter x: value tensor
/// - Parameter result: the scalar tensor where the result will be written
/// - Precondition: Each value in `axes` must be in the range `-rank..<rank`.
@inlinable
public func all<S>(_ x: Tensor<S,Bool>, alongAxes axes: Set<Int>? = nil)
    -> Tensor<S,Bool> where S: TensorShape
{
    let resultShape = x.reductionShape(alongAxes: axes)
    var result = Tensor<S,Bool>(resultShape)
    copy(from: x[S.zero, resultShape], to: &result)
    Context.currentQueue.reduce(x, &result, .compare, { $0 && $1 }, nil)
    return result
}

/// - Parameter along: the axes to operate on
/// - Returns: a new tensor containing the result
public extension Tensor where Element == Bool {
    @inlinable func all(alongAxes axes: Set<Int>? = nil) -> Self {
        SwiftRT.all(self, alongAxes: axes)
    }
    
    @inlinable
    func all(alongAxes axes: Int...) -> Self { all(alongAxes: Set(axes)) }
}

//==============================================================================
/// any(x:along:)
/// Returns `true` if any value is equal to `true` along the specified
/// axes. Otherwise returns `false`. The result extent along the specified
/// axes will be 1. Rank is not reduced.
/// - Parameter x: value tensor
/// - Parameter axes: the axes to operate on
/// - Returns: a new tensor containing the result
@inlinable
public func any<S>(_ x: Tensor<S,Bool>, alongAxes axes: Set<Int>? = nil)
    -> Tensor<S,Bool> where S: TensorShape
{
    let resultShape = x.reductionShape(alongAxes: axes)
    var result = Tensor<S,Bool>(resultShape)
    copy(from: x[S.zero, resultShape], to: &result)
    Context.currentQueue.reduce(x, &result, .compare, { $0 || $1 }, nil)
    return result
}

/// - Parameter axes: the axes to operate on
/// - Returns: a new tensor containing the result
public extension Tensor where Element == Bool {
    @inlinable func any(alongAxes axes: Set<Int>? = nil) -> Self {
        SwiftRT.any(self, alongAxes: axes)
    }

    @inlinable func any(alongAxes axes: Int...) -> Self {
        any(alongAxes: Set(axes))
    }
}

//==============================================================================
/// sum(x:along:
/// Sums `x` along the specified axes
/// - Parameter x: value tensor
/// - Parameter along: the axes to operate on
@inlinable
public func sum<S,E>(_ x: Tensor<S,E>, alongAxes axes: Set<Int>? = nil)
    -> Tensor<S,E> where S: TensorShape, E: Numeric
{
    let resultShape = x.reductionShape(alongAxes: axes)
    var result = Tensor<S,E>(zeros: resultShape)
    Context.currentQueue.reduce(x, &result, .add, +, nil)
    return result
}

@derivative(of: sum)
@inlinable func _vjpSum<S,E>(_ x: Tensor<S,E>, alongAxes axes: Set<Int>? = nil)
    -> (value: Tensor<S,E>, pullback: (Tensor<S,E>) -> Tensor<S,E>)
    where S: TensorShape, E: DifferentiableElement
{
    let value = sum(x, alongAxes: axes)
    return (value, { [xshape = x.shape] in
        Tensor<S,E>(repeating: $0, to: xshape)
    })
}

public extension Tensor where Element: Numeric {
    @differentiable(where Element: DifferentiableElement)
    @inlinable func sum(alongAxes axes: Set<Int>? = nil) -> Self {
        SwiftRT.sum(self, alongAxes: axes)
    }

    @differentiable(where Element: DifferentiableElement)
    @inlinable func sum(alongAxes axes: Int...) -> Self {
        sum(alongAxes: Set(axes))        
    }
}

//==============================================================================
/// mean(x:along:
/// mean of `x` along the specified axes
///
/// - Parameter x: value tensor
/// - Parameter along: the axes to operate on
@inlinable public func mean<S,E>(
    _ x: Tensor<S,E>,
    alongAxes axes: Set<Int>? = nil
) -> Tensor<S,E> where S: TensorShape, E: AlgebraicField
{
    // the divisor is the product of the `axes` that are summed
    let divisor = (axes?.reduce(E.one) {
        $0 * E(exactly: x.shape[$1])!
    }) ?? E(exactly: x.count)!

    var result = Tensor<S,E>(zeros: x.reductionShape(alongAxes: axes))
    Context.currentQueue.reduce(x, &result, .add, +, { $0 / divisor })
    return result
}

@derivative(of: mean)
@inlinable func _vjpMean<S,E>(
    _ x: Tensor<S,E>,
    alongAxes axes: Set<Int>? = nil
) -> (value: Tensor<S,E>, pullback: (Tensor<S,E>) -> Tensor<S,E>)
    where S: TensorShape, E: DifferentiableElement & AlgebraicField
{
    let value = x.mean(alongAxes: axes)
    let count = E(exactly: x.count)!
    return (value, { [xshape = x.shape] in
        Tensor<S,E>(repeating: $0, to: xshape) / count
    })
}

public extension Tensor where Element: AlgebraicField {
    @differentiable(where Element: DifferentiableElement)
    @inlinable func mean(alongAxes axes: Set<Int>? = nil) -> Self {
        SwiftRT.mean(self, alongAxes: axes)
    }

    @differentiable(where Element: DifferentiableElement)
    @inlinable func mean(alongAxes axes: Int...) -> Self {
        mean(alongAxes: Set(axes))
    }
}

//==============================================================================
/// prod(x:along:
/// prod of `x` along the specified axes
/// - Parameter x: value tensor
/// - Parameter along: the axes to operate on
@inlinable public func prod<S,E>(
    _ x: Tensor<S,E>,
    alongAxes axes: Set<Int>? = nil
) -> Tensor<S,E> where S: TensorShape, E: Numeric
{
    var result = Tensor<S,E>(zeros: x.reductionShape(alongAxes: axes))
    Context.currentQueue.reduce(x, &result, .mul, { $0 * $1 }, nil)
    return result
}

@derivative(of: prod)
@inlinable func _vjpProd<S,E>(
    _ x: Tensor<S,E>,
    alongAxes axes: Set<Int>? = nil
) -> (value: Tensor<S,E>, pullback: (Tensor<S,E>) -> Tensor<S,E>)
    where S: TensorShape, E: DifferentiableElement
{
    let value = prod(x, alongAxes: axes)
    return (value, { [xshape = x.shape] in
        Tensor<S,E>(repeating: $0, to: xshape)
    })
}

public extension Tensor where Element: Numeric {
    @differentiable(where Element: DifferentiableElement)
    @inlinable func prod(alongAxes axes: Set<Int>? = nil) -> Self {
        SwiftRT.prod(self, alongAxes: axes)
    }

    @differentiable(where Element: DifferentiableElement)
    @inlinable func prod(alongAxes axes: Int...) -> Self {
        prod(alongAxes: Set(axes))
    }
}

//==============================================================================
/// prodNonZeros(x:along:
/// product of non zero values of `x` along the specified axes
/// - Parameter x: value tensor
/// - Parameter along: the axes to operate on
@inlinable public func prodNonZeros<S,E>(
    _ x: Tensor<S,E>,
    alongAxes axes: Set<Int>? = nil
) -> Tensor<S,E> where S: TensorShape, E: Numeric
{
    var result = Tensor<S,E>(zeros: x.reductionShape(alongAxes: axes))
    Context.currentQueue.reduce(x, &result, .mulNonZeros,
                                { $1 == 0 ? $0 : $0 * $1 }, nil)
    return result
}

@derivative(of: prodNonZeros)
@inlinable func _vjpProdNonZeros<S,E>(
    _ x: Tensor<S,E>,
    alongAxes axes: Set<Int>? = nil
) -> (value: Tensor<S,E>, pullback: (Tensor<S,E>) -> Tensor<S,E>)
    where S: TensorShape, E: DifferentiableElement
{
    // REVIEW: this is probably wrong
    let value = prodNonZeros(x, alongAxes: axes)
    return (value, { [xshape = x.shape] in
        Tensor<S,E>(repeating: $0, to: xshape)
    })
}

public extension Tensor where Element: Numeric {
    @differentiable(where Element: DifferentiableElement)
    @inlinable func prodNonZeros(alongAxes axes: Set<Int>? = nil) -> Self {
        SwiftRT.prodNonZeros(self, alongAxes: axes)
    }

    @differentiable(where Element: DifferentiableElement)
    @inlinable func prodNonZeros(alongAxes axes: Int...) -> Self {
        prodNonZeros(alongAxes: Set(axes))
    }
}

//==============================================================================
/// min(x:along:
/// returns the minimum element value of `x` along the specified axes
/// TODO: add optional indices
/// - Parameter x: value tensor
/// - Parameter along: the axes to operate on
@inlinable public func min<S,E>(
    _ x: Tensor<S,E>,
    alongAxes axes: Set<Int>? = nil
) -> Tensor<S,E> where S: TensorShape, E: Comparable
{
    var result = Tensor<S,E>(x.reductionShape(alongAxes: axes))
    copy(from: x[S.zero, result.shape], to: &result)
    Context.currentQueue.reduce(x, &result, .min, { $0 <= $1 ? $0 : $1 }, nil)
    return result
}


@derivative(of: min)
@inlinable func _vjpMin<S,E>(_ x: Tensor<S,E>, alongAxes axes: Set<Int>? = nil)
    -> (value: Tensor<S,E>, pullback: (Tensor<S,E>) -> Tensor<S,E>)
    where S: TensorShape, E: DifferentiableElement & Comparable
{
    fatalError()
}

public extension Tensor where Element: Comparable
{
    @differentiable(where Element: DifferentiableElement)
    @inlinable func min(alongAxes axes: Set<Int>? = nil) -> Self {
        SwiftRT.min(self, alongAxes: axes)
    }

    @differentiable(where Element: DifferentiableElement)
    @inlinable func min(alongAxes axes: Int...) -> Self {
        min(alongAxes: Set(axes))
    }
}

//==============================================================================
/// max(x:along:
/// returns the maximum element value of `x` along the specified axes
/// - Parameter x: value tensor
/// - Parameter along: the axes to operate on
@inlinable public func max<S,E>(
    _ x: Tensor<S,E>,
    alongAxes axes: Set<Int>? = nil
) -> Tensor<S,E> where S: TensorShape, E: Comparable
{
    var result = Tensor<S,E>(x.reductionShape(alongAxes: axes))
    copy(from: x[S.zero, result.shape], to: &result)
    Context.currentQueue.reduce(x, &result, .max, { $0 >= $1 ? $0 : $1 }, nil)
    return result
}


@derivative(of: max)
@inlinable func _vjpMax<S,E>(_ x: Tensor<S,E>, alongAxes axes: Set<Int>? = nil)
    -> (value: Tensor<S,E>, pullback: (Tensor<S,E>) -> Tensor<S,E>)
    where S: TensorShape, E: DifferentiableElement & Comparable
{
    fatalError()
}

public extension Tensor where Element: Comparable
{
    @differentiable(where Element: DifferentiableElement)
    @inlinable func max(alongAxes axes: Set<Int>? = nil) -> Self {
        SwiftRT.min(self, alongAxes: axes)
    }

    @differentiable(where Element: DifferentiableElement)
    @inlinable func max(alongAxes axes: Int...) -> Self {
        min(alongAxes: Set(axes))
    }
}

////==============================================================================
///// absmax(x:along:
///// absolute max of `x` along the specified axes
///// - Parameter x: value tensor
///// - Parameter along: the axes to operate on
@inlinable public func absmax<S,E>(
    _ x: Tensor<S,E>,
    alongAxes axes: Set<Int>? = nil
) -> Tensor<S,E> where S: TensorShape, E: SignedNumeric & Comparable
{
    var result = Tensor<S,E>(x.reductionShape(alongAxes: axes))
    copy(from: x[S.zero, result.shape], to: &result)
    Context.currentQueue.reduce(x, &result, .amax, {
        Swift.max(Swift.abs($0), Swift.abs($1))
    }, nil)
    return result
}


@derivative(of: absmax)
@inlinable func _vjpAbsmax<S,E>(_ x: Tensor<S,E>, alongAxes axes: Set<Int>? = nil)
    -> (value: Tensor<S,E>, pullback: (Tensor<S,E>) -> Tensor<S,E>)
    where S: TensorShape, E: DifferentiableElement & SignedNumeric & Comparable
{
    fatalError()
}

public extension Tensor where Element: SignedNumeric & Comparable
{
    @differentiable(where Element: DifferentiableElement)
    @inlinable func absmax(alongAxes axes: Set<Int>? = nil) -> Self {
        SwiftRT.absmax(self, alongAxes: axes)
    }

    @differentiable(where Element: DifferentiableElement)
    @inlinable func absmax(alongAxes axes: Int...) -> Self {
        absmax(alongAxes: Set(axes))
    }
}

//==============================================================================
/// abssum(x:along:
/// Sums the absolute values of `x` along the specified axes
/// - Parameter x: value tensor
/// - Parameter along: the axes to operate on
@inlinable public func abssum<S,E>(
    _ x: Tensor<S,E>,
    alongAxes axes: Set<Int>? = nil
) -> Tensor<S,E> where S: TensorShape, E: SignedNumeric & Comparable
{
    var result = Tensor<S,E>(zeros: x.reductionShape(alongAxes: axes))
    Context.currentQueue.reduce(x, &result, .asum, { $0 + Swift.abs($1) }, nil)
    return result
}

@derivative(of: abssum)
@inlinable func _vjpAbsSum<S,E>(_ x: Tensor<S,E>, alongAxes axes: Set<Int>? = nil)
    -> (value: Tensor<S,E>, pullback: (Tensor<S,E>) -> Tensor<S,E>)
    where S: TensorShape, E: DifferentiableElement & SignedNumeric & Comparable
{
    fatalError()
}

public extension Tensor where Element: SignedNumeric & Comparable {
    @differentiable(where Element: DifferentiableElement)
    @inlinable func abssum(alongAxes axes: Set<Int>? = nil) -> Self {
        SwiftRT.abssum(self, alongAxes: axes)
    }

    @differentiable(where Element: DifferentiableElement)
    @inlinable func abssum(alongAxes axes: Int...) -> Self {
        abssum(alongAxes: Set(axes))
    }
}

//==============================================================================
/// sqrtSumSquares(x:along:
/// Square root of the sum `x` along the specified axes
/// - Parameter x: value tensor
/// - Parameter along: the axes to operate on
@inlinable public func sqrtSumSquares<S,E>(
    _ x: Tensor<S,E>,
    alongAxes axes: Set<Int>? = nil
) -> Tensor<S,E> where S: TensorShape, E: Real
{
    var result = Tensor<S,E>(zeros: x.reductionShape(alongAxes: axes))
    Context.currentQueue.reduce(x, &result, .sqrtSumSquares,
                        { $0 + $1 * $1 }, { .sqrt($0) })
    return result
}

@derivative(of: sqrtSumSquares)
@inlinable func _vjpSqrtSumSquares<S,E>(
    _ x: Tensor<S,E>,
    alongAxes axes: Set<Int>? = nil
) -> (value: Tensor<S,E>, pullback: (Tensor<S,E>) -> Tensor<S,E>)
    where S: TensorShape, E: DifferentiableElement & Real
{
    fatalError()
}

public extension Tensor where Element: Real {
    @differentiable(where Element: DifferentiableElement)
    @inlinable func sqrtSumSquares(alongAxes axes: Set<Int>? = nil) -> Self {
        SwiftRT.sqrtSumSquares(self, alongAxes: axes)
    }

    @differentiable(where Element: DifferentiableElement)
    @inlinable func sqrtSumSquares(alongAxes axes: Int...) -> Self {
        sqrtSumSquares(alongAxes: Set(axes))
    }
}
