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
import Foundation
import Numerics

//==============================================================================
// Random initializers
public extension Tensor where TensorElement.Value: BinaryFloatingPoint {
    //--------------------------------------------------------------------------
    // `init(randomUniform`
    /// Creates a tensor with the specified shape, randomly sampling scalar
    /// values from a uniform distribution between `lower` and `upper`
    ///
    /// - Parameters:
    ///  - shape: The dimensions of the tensor
    ///  - lower: The lower bound of the distribution
    ///  - upper: The upper bound of the distribution
    ///  - layout: element storage layout
    ///  - seed: The seed value
    init(randomUniform shape: Shape,
         lower: Element = 0,
         upper: Element = 1,
         layout: Layout = Layout.defaultValue,
         seed: RandomSeed = Context.randomSeed)
    {
        self = Self(shape: shape, layout: layout)
        Context.currentQueue.fill(randomUniform: &self, lower, upper, seed)
    }
    
    //--------------------------------------------------------------------------
    /// Creates a tensor with the specified shape, randomly sampling
    /// scalar values from a normal distribution.
    ///
    /// - Parameters:
    ///  - shape: The dimensions of the tensor
    ///  - mean: The mean of the distribution
    ///  - std: The standard deviation of the distribution
    ///  - layout: element storage layout
    ///  - seed: The seed value
    init(randomNormal shape: Shape,
         mean: Element = 0,
         std: Element = 1,
         layout: Layout = Layout.defaultValue,
         seed: RandomSeed = Context.randomSeed)
    {
        self = Self(shape: shape, layout: layout)
        Context.currentQueue.fill(randomNormal: &self, mean, std, seed)
    }
    
    //------------------------------------
    // tensor parameter version
    init(randomNormal shape: Shape,
         mean: Self,
         std: Self,
         layout: Layout = Layout.defaultValue,
         seed: RandomSeed = Context.randomSeed)
    {
        self = Self(shape: shape, layout: layout)
        Context.currentQueue.fill(randomNormal: &self, mean, std, seed)
    }
    
    //--------------------------------------------------------------------------
    /// Creates a tensor with the specified shape, randomly sampling scalar
    /// values from a truncated Normal distribution.
    ///
    /// - Parameters:
    ///  - shape: The dimensions of the tensor.
    ///  - mean: The mean of the distribution.
    ///  - std: The standard deviation of the distribution.
    ///  - layout: element storage layout
    ///  - seed: The seed value.
    init(randomTruncatedNormal shape: Shape,
         mean: Element = 0,
         std: Element = 1,
         layout: Layout = Layout.defaultValue,
         seed: RandomSeed = Context.randomSeed)
    {
        self = Self(shape: shape, layout: layout)
        Context.currentQueue.fill(randomTruncatedNormal: &self, mean, std, seed)
    }
    
    //------------------------------------
    // tensor parameter version
    init(randomTruncatedNormal shape: Shape,
         mean: Self,
         std: Self,
         layout: Layout = Layout.defaultValue,
         seed: RandomSeed = Context.randomSeed)
    {
        self = Self(shape: shape, layout: layout)
        Context.currentQueue.fill(randomTruncatedNormal: &self, mean, std, seed)
    }
}

public extension Tensor where Element == DeviceIndex {
    //--------------------------------------------------------------------------
    /// Creates a tensor by drawing samples from a categorical distribution.
    ///
    /// - Parameters:
    ///   - randomCategorialLogits: 2-D Tensor with shape
    ///     [batchSize, classCount]`.  Each slice `[i, :]` represents the
    ///      unnormalized log probabilities for all classes.
    ///   - sampleCount: 0-D.  Number of independent samples to draw
    ///   - layout: element storage layout
    ///     for each row slice.
    ///   - seed: The seed value.
    ///
    /// - Returns: 2-D Tensor with shape `[batchSize, sampleCount]`.
    ///   Each slice `[i, ...]`contains the drawn class labels with
    ///   range `[0, classCount)`.
    init<E>(randomCategorialLogits: Tensor<Shape,E>,
            sampleCount: Int,
            layout: Layout = Layout.defaultValue,
            seed: RandomSeed = Context.randomSeed)
    where E: Numeric
    {
        fatalError()
    }
}

//==============================================================================
// Random initializers with variance scaling
fileprivate extension TensorShape {
    // Returns the `fanIn` and `fanOut` counts for `TensorShape`s where
    // the last two axes represent the input channel count and output
    // channel count, respectively.
    func fans() -> (in: Int, out: Int) {
        precondition(count > 1, "Fans cannot be computed for tensors with" +
                        " fewer than 2 dimensions. Got: \(count)")
        
        // Fans for a 2-D tensor, e.g. `Dense`/`Embedding` weights.
        if count == 2 {
            return (self[0], self[1])
        }
        
        // Fans for tensors with rank greater than `2`, specifically
        // convolution filters.
        let lastSpatialAxis = indices.endIndex - 3
        let spatialSize = lastSpatialAxis + 1
        let inputAxis = indices.endIndex - 2
        let fanIn = self[inputAxis] * spatialSize
        let outputAxis = indices.endIndex - 1
        let fanOut = self[outputAxis] * spatialSize
        return (fanIn, fanOut)
    }
}

public extension Tensor where TensorElement.Value: Real & BinaryFloatingPoint {
    //--------------------------------------------------------------------------
    /// Creates a tensor with the specified shape by performing
    /// Glorot (Xavier) uniform initialization.
    ///
    /// It draws random samples from a uniform distribution between
    /// `-limit` and `limit`generated by the default random number
    /// generator, where `limit`is sqrt(6 / (fanIn + fanOut))` and
    /// `fanIn`/`fanOut` represent the number of input and output
    /// features multiplied by the receptive field size.
    ///
    /// Reference: ["Understanding the difficulty of training deep
    /// feedforward neural networks"](
    /// http://proceedings.mlr.press/v9/glorot10a/glorot10a.pdf)
    ///
    /// - Parameters:
    ///   - shape: The dimensions of the tensor.
    ///   - layout: element storage layout
    ///   - seed: The seed value.
    init(glorotUniform shape: Shape,
         layout: Layout = Layout.defaultValue,
         seed: RandomSeed = Context.randomSeed
    ) {
        let (fanIn, fanOut) = shape.fans()
        let limit = Element.sqrt(6 / Element(fanIn + fanOut))
        self.init(randomUniform: shape,
                  lower: -limit,
                  upper: limit,
                  layout: layout,
                  seed: seed)
    }
    
    //--------------------------------------------------------------------------
    /// Creates a tensor with the specified shape by performing
    /// Glorot (Xavier) normal initialization.
    ///
    /// It draws random samples from a truncated normal distribution
    /// centered on `0` with standard deviation `sqrt(2 / (fanIn + fanOut))
    /// generated by the default random number generator, where
    /// `fanIn`/`fanOut` represent the number of input and output features
    /// multiplied by the receptive field size.
    ///
    /// Reference: ["Understanding the difficulty of training deep
    /// feedforward neural networks"](
    /// http://proceedings.mlr.press/v9/glorot10a/glorot10a.pdf)
    ///
    /// - Parameters:
    ///   - shape: The dimensions of the tensor.
    ///   - layout: element storage layout
    ///   - seed: The seed value.
    init(glorotNormal shape: Shape,
         layout: Layout = Layout.defaultValue,
         seed: RandomSeed = Context.randomSeed
    ) {
        let (fanIn, fanOut) = shape.fans()
        var std = Element.sqrt(2 / Element(fanIn + fanOut))
        // Standard deviation of truncated standard normal between
        // `-2` and `2` standard deviations.
        let truncationDeviation = Element(0.87962566103423978)
        // Smooth the tails of the clipped normal.
        std /= truncationDeviation
        self.init(randomTruncatedNormal: shape,
                  mean: 0, std: std, layout: layout, seed: seed)
    }
    
    //--------------------------------------------------------------------------
    /// Creates a tensor with the specified shape by performing
    /// He (Kaiming) uniform initialization.
    ///
    /// It draws random samples from a uniform distribution between
    /// `-limit` and `limit` generated by the default random number
    /// generator, where `limit` is `sqrt(6 / fanIn)` and `fanIn`
    /// represents the number of input features multiplied by the
    /// receptive field size.
    ///
    /// Reference: ["Delving Deep into Rectifiers: Surpassing Human-Level
    /// Performance on ImageNet
    /// Classification"](https://www.cv-foundation.org/openaccess/content_iccv_2015/papers/He_Delving_Deep_into_ICCV_2015_paper.pdf)
    ///
    /// - Parameters:
    ///   - shape: The dimensions of the tensor.
    ///   - layout: element storage layout
    ///   - seed: The seed value.
    init(heUniform shape: Shape,
         layout: Layout = Layout.defaultValue,
         seed: RandomSeed = Context.randomSeed
    ) {
        let (fanIn, _) = shape.fans()
        let limit = Element.sqrt(6 / Element(fanIn))
        self.init(randomUniform: shape, lower: -limit,
                  upper: limit, layout: layout, seed: seed)
    }
    
    //--------------------------------------------------------------------------
    /// Creates a tensor with the specified shape by performing
    /// He (Kaiming) normal initialization.
    ///
    /// It draws random samples from a truncated normal distribution
    /// centered on `0` with standard deviation `sqrt(2 / fanIn))` generated
    /// by the default random number generator, where `fanIn` represents the
    /// number of input features multiplied by the receptive field size.
    ///
    /// Reference: ["Delving Deep into Rectifiers: Surpassing Human-Level
    /// Performance on ImageNet
    /// Classification"](https://www.cv-foundation.org/openaccess/content_iccv_2015/papers/He_Delving_Deep_into_ICCV_2015_paper.pdf)
    ///
    /// - Parameters:
    ///   - shape: The dimensions of the tensor.
    ///   - layout: element storage layout
    ///   - seed: The seed value.
    init(heNormal shape: Shape,
         layout: Layout = Layout.defaultValue,
         seed: RandomSeed = Context.randomSeed
    ) {
        let (fanIn, _) = shape.fans()
        var std = Element.sqrt(2 / Element(fanIn))
        // Standard deviation of truncated standard normal between `-2` and `2` standard deviations.
        let truncationDeviation = Element(0.87962566103423978)
        // Smooth the tails of the clipped normal.
        std /= truncationDeviation
        self.init(randomTruncatedNormal: shape,
                  mean: 0, std: std, layout: layout,
                  seed: seed)
    }
    
    //--------------------------------------------------------------------------
    /// Creates a tensor with the specified shape by performing LeCun
    /// uniform initialization.
    ///
    /// It draws random samples from a uniform distribution between
    /// `-limit` and `limit` generated by the default random number
    /// generator, where `limit` is `sqrt(3 / fanIn)` and `fanIn` represents
    /// the number of input features multiplied by the receptive field size.
    ///
    /// Reference: ["Efficient BackProp"](http://yann.lecun.com/exdb/publis/pdf/lecun-98b.pdf)
    ///
    /// - Parameters:
    ///   - shape: The dimensions of the tensor.
    ///   - layout: element storage layout
    ///   - seed: The seed value.
    init(leCunUniform shape: Shape,
         layout: Layout = Layout.defaultValue,
         seed: RandomSeed = Context.randomSeed
    ) {
        let (fanIn, _) = shape.fans()
        let limit = Element.sqrt(3 / Element(fanIn))
        self.init(randomUniform: shape, lower: -limit,
                  upper: limit, layout: layout, seed: seed)
    }
    
    //--------------------------------------------------------------------------
    /// Creates a tensor with the specified shape by performing LeCun
    /// normal initialization.
    ///
    /// It draws random samples from a truncated normal distribution
    /// centered on `0` with standard deviation `sqrt(1 / fanIn)` generated
    /// by the default random number generator, where `fanIn` represents
    /// the number of input features multiplied by the receptive field size.
    ///
    /// Reference: ["Efficient BackProp"](http://yann.lecun.com/exdb/publis/pdf/lecun-98b.pdf)
    ///
    /// - Parameters:
    ///   - shape: The dimensions of the tensor.
    ///   - layout: element storage layout
    ///   - seed: The seed value.
    init(leCunNormal shape: Shape,
         layout: Layout = Layout.defaultValue,
         seed: RandomSeed = Context.randomSeed
    ) {
        let (fanIn, _) = shape.fans()
        var std = Element.sqrt(1 / Element(fanIn))
        // Standard deviation of truncated standard normal between
        // `-2` and `2` standard deviations.
        let truncationDeviation = Element(0.87962566103423978)
        // Smooth the tails of the clipped normal.
        std /= truncationDeviation
        self.init(randomTruncatedNormal: shape,
                  mean: 0, std: std, layout: layout,
                  seed: seed)
    }
}

//==============================================================================
// convenience syntax functions
public extension Tensor where
    Shape == Shape1,
    TensorElement.Value: Real & BinaryFloatingPoint
{
    init(
        randomTruncatedNormal shape: Int,
        mean: Self,
        std: Self,
        layout: Layout = Layout.defaultValue,
        seed: RandomSeed = Context.randomSeed
    ) {
        self.init(randomTruncatedNormal: Shape(shape),
                  mean: mean, std: std, layout: layout, seed: seed)
    }

    init(randomTruncatedNormal shape: Int,
         mean: Element = 0,
         std: Element = 1,
         layout: Layout = Layout.defaultValue,
         seed: RandomSeed = Context.randomSeed
    ) {
        self.init(randomTruncatedNormal: Shape(shape),
                  mean: mean, std: std, layout: layout, seed: seed)
    }

    init(randomNormal shape: Int, mean: Self,
         std: Self,
         layout: Layout = Layout.defaultValue,
         seed: RandomSeed = Context.randomSeed
    ) {
        self.init(randomNormal: Shape(shape),
                  mean: mean, std: std, layout: layout, seed: seed)
    }

    init(randomNormal shape: Int,
         mean: Element = 0,
         std: Element = 1,
         layout: Layout = Layout.defaultValue,
         seed: RandomSeed = Context.randomSeed
    ) {
        self.init(randomNormal: Shape(shape),
                  mean: mean, std: std, layout: layout, seed: seed)
    }

    init(randomUniform shape: Int,
         lower: Element = 0,
         upper: Element = 1,
         layout: Layout = Layout.defaultValue,
         seed: RandomSeed = Context.randomSeed
    ) {
        self.init(randomUniform: Shape(shape),
                  lower: lower, upper: upper, layout: layout, seed: seed)
    }

    init(glorotUniform shape: Int,
         layout: Layout = Layout.defaultValue,
         seed: RandomSeed = Context.randomSeed
    ) {
        self.init(glorotUniform: Shape(shape), layout: layout, seed: seed)
    }
        
    init(glorotNormal shape: Int,
         layout: Layout = Layout.defaultValue,
         seed: RandomSeed = Context.randomSeed
    ) {
        self.init(glorotNormal: Shape(shape), layout: layout, seed: seed)
    }
    
    init(heUniform shape: Int,
         layout: Layout = Layout.defaultValue,
         seed: RandomSeed = Context.randomSeed
    ) {
        self.init(heUniform: Shape(shape), layout: layout, seed: seed)
    }
    
    init(heNormal shape: Int,
         layout: Layout = Layout.defaultValue,
         seed: RandomSeed = Context.randomSeed
    ) {
        self.init(heNormal: Shape(shape), layout: layout, seed: seed)
    }
    
    init(leCunUniform shape: Int,
         layout: Layout = Layout.defaultValue,
         seed: RandomSeed = Context.randomSeed
    ) {
        self.init(leCunUniform: Shape(shape), layout: layout, seed: seed)
    }
    
    init(leCunNormal shape: Int,
         layout: Layout = Layout.defaultValue,
         seed: RandomSeed = Context.randomSeed
    ) {
        self.init(leCunNormal: Shape(shape), layout: layout, seed: seed)
    }
}

