// Copyright 2019 The TensorFlow Authors. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// Original source:
// "Imagenette"
// Jeremy Howard
// https://github.com/fastai/imagenette

import Foundation
import ModelSupport
import TensorFlow

public struct Imagenette: ImageClassificationDataset {
    public let trainingDataset: Dataset<LabeledExample>
    public let testDataset: Dataset<LabeledExample>
    public let trainingExampleCount = 12894
    public let testExampleCount = 500

    public enum ImageSize {
        case full
        case resized160
        case resized320

        var suffix: String {
            switch self {
            case .full: return ""
            case .resized160: return "-160"
            case .resized320: return "-320"
            }
        }
    }

    public init() {
        self.init(inputSize: .resized320, outputSize: 224)
    }

    public init(
        inputSize: ImageSize, outputSize: Int,
        localStorageDirectory: URL = FileManager.default.temporaryDirectory.appendingPathComponent(
            "Imagenette")
    ) {
        do {
            self.trainingDataset = Dataset<LabeledExample>(
                elements: try loadImagenetteTrainingImages(
                    inputSize: inputSize, outputSize: outputSize,
                    localStorageDirectory: localStorageDirectory))
            self.testDataset = Dataset<LabeledExample>(
                elements: try loadImagenetteValidationImages(
                    inputSize: inputSize, outputSize: outputSize,
                    localStorageDirectory: localStorageDirectory))
        } catch {
            fatalError("Could not load Imagenette dataset: \(error)")
        }
    }
}

func downloadImagenetteIfNotPresent(to directory: URL, size: Imagenette.ImageSize) {
    let downloadPath = directory.appendingPathComponent("imagenette\(size.suffix)").path
    let directoryExists = FileManager.default.fileExists(atPath: downloadPath)
    let contentsOfDir = try? FileManager.default.contentsOfDirectory(atPath: downloadPath)
    let directoryEmpty = (contentsOfDir == nil) || (contentsOfDir!.isEmpty)

    guard !directoryExists || directoryEmpty else { return }

    let location = URL(
        string: "https://s3.amazonaws.com/fast-ai-imageclas/imagenette\(size.suffix).tgz")!
    let _ = DatasetUtilities.downloadResource(
        filename: "imagenette\(size.suffix)", fileExtension: "tgz",
        remoteRoot: location.deletingLastPathComponent(), localStorageDirectory: directory)
}

func loadImagenetteDirectory(
    named name: String, in directory: URL, inputSize: Imagenette.ImageSize, outputSize: Int
) throws -> LabeledExample {
    downloadImagenetteIfNotPresent(to: directory, size: inputSize)
    let path = directory.appendingPathComponent("imagenette\(inputSize.suffix)/\(name)")
    let dirContents = try FileManager.default.contentsOfDirectory(
        at: path, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])

    var imageData: [Float] = []
    var stringLabels: [String] = []
    var labels: [Int32] = []
    var currentLabel: Int32 = 0
    var imageCount = 0
    for directoryURL in dirContents {
        stringLabels.append(directoryURL.lastPathComponent)

        let subdirContents = try FileManager.default.contentsOfDirectory(
            at: directoryURL, includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles])
        for fileURL in subdirContents {
            let image = Image(jpeg: fileURL)
            let resizedImage = image.resized(to: (outputSize, outputSize))
            let scaledImage = resizedImage.tensor / 255.0
            imageData.append(contentsOf: scaledImage.scalars)

            labels.append(currentLabel)

            imageCount += 1
        }
        currentLabel += 1
    }

    let labelTensor = Tensor<Int32>(shape: [imageCount], scalars: labels)
    let imageTensor = Tensor<Float>(
        shape: [imageCount, outputSize, outputSize, 3], scalars: imageData)

    return LabeledExample(label: labelTensor, data: imageTensor)
}

func loadImagenetteTrainingImages(
    inputSize: Imagenette.ImageSize, outputSize: Int, localStorageDirectory: URL
) throws
    -> LabeledExample
{
    return try loadImagenetteDirectory(
        named: "train", in: localStorageDirectory, inputSize: inputSize, outputSize: outputSize)
}

func loadImagenetteValidationImages(
    inputSize: Imagenette.ImageSize, outputSize: Int, localStorageDirectory: URL
) throws
    -> LabeledExample
{
    return try loadImagenetteDirectory(
        named: "val", in: localStorageDirectory, inputSize: inputSize, outputSize: outputSize)
}
