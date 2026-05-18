classdef LocalRegistrationEstimatorTest < matlab.unittest.TestCase
    %LocalRegistrationEstimatorTest Unit tests for local normalized correlation.

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            srcFolder = fullfile(fileparts(fileparts(mfilename("fullpath"))), "src");
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(srcFolder));
        end
    end

    methods (Test)
        function estimatePatchShiftReturnsMovingToReferenceShift(testCase)
            referencePatch = LocalRegistrationEstimatorTest.createTexture([80 96], 7);
            movingPatch = circshift(referencePatch, [4, -6]);

            [patchShift, peakValue] = ...
                anchor.LocalRegistrationEstimator.estimatePatchShift( ...
                referencePatch, movingPatch);

            testCase.verifyEqual(patchShift, [7 -5], AbsTol=0.25);
            testCase.verifyGreaterThan(peakValue, 0.5);
        end

        function estimateCorrectsInitialViewportTranslation(testCase)
            imageData = LocalRegistrationEstimatorTest.createTexture([260 320], 11);
            source = anchor.MatrixImageSource(imageData, "Synthetic");
            focusedState = anchor.ViewportState([80.5 207.5], [70.5 165.5]);
            initialOtherState = focusedState.translate([-7, 5]);
            estimator = anchor.LocalRegistrationEstimator();

            result = estimator.estimate(source, source, focusedState, initialOtherState);

            testCase.verifyEqual(result.ImageShift, [7 -5], AbsTol=0.35);
            testCase.verifyEqual(result.TargetViewportState.getCenter(), ...
                focusedState.getCenter(), AbsTol=0.35);
        end

        function estimateUsesFocusedViewportOutputSize(testCase)
            imageData = LocalRegistrationEstimatorTest.createTexture([260 320], 11);
            source = anchor.MatrixImageSource(imageData, "Synthetic");
            focusedState = anchor.ViewportState([80.5 207.5], [70.5 165.5]);
            initialOtherState = focusedState.translate([-7, 5]);
            estimator = anchor.LocalRegistrationEstimator();

            result = estimator.estimate(source, source, focusedState, initialOtherState);

            testCase.verifyEqual(result.OutputSize, [95 127]);
        end

        function estimateHandlesNonSquareUint8Images(testCase)
            imageData = uint8(255 * LocalRegistrationEstimatorTest.createTexture([311 997], 13));
            source = anchor.MatrixImageSource(imageData, "Wide synthetic");
            focusedState = anchor.ViewportState([420.5 580.5], [110.5 185.5]);
            initialOtherState = focusedState.translate([9, -6]);
            estimator = anchor.LocalRegistrationEstimator();

            result = estimator.estimate(source, source, focusedState, initialOtherState);

            testCase.verifyEqual(result.OutputSize, [75 160]);
            testCase.verifyEqual(result.ImageShift, [-9 6], AbsTol=0.35);
            testCase.verifyEqual(result.TargetViewportState.getCenter(), ...
                focusedState.getCenter(), AbsTol=0.35);
        end

        function estimatePatchShiftReturnsZeroForFlatPatches(testCase)
            referencePatch = ones(24, 32);
            movingPatch = ones(24, 32);

            [patchShift, peakValue] = ...
                anchor.LocalRegistrationEstimator.estimatePatchShift( ...
                referencePatch, movingPatch);

            testCase.verifyEqual(patchShift, [0 0]);
            testCase.verifyEqual(peakValue, 0);
        end
    end

    methods (Static, Access = private)
        function imageData = createTexture(imageSize, seed)
            previousState = rng(seed);
            restoreRng = onCleanup(@() rng(previousState));
            imageData = rand(imageSize);
            imageData = conv2(imageData, ones(7) / 49, "same");
            clear restoreRng
        end
    end
end
