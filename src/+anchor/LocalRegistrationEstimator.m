classdef LocalRegistrationEstimator
    %LocalRegistrationEstimator Estimates local translation from view patches.

    properties (SetAccess = private)
        MinimumPatchSize (1, 1) double = 2
    end

    methods
        function result = estimate(estimator, focusedSource, nonFocusedSource, ...
                focusedState, initialNonFocusedState)
            arguments
                estimator anchor.LocalRegistrationEstimator
                focusedSource anchor.MatrixImageSource
                nonFocusedSource anchor.MatrixImageSource
                focusedState anchor.ViewportState
                initialNonFocusedState anchor.ViewportState
            end

            outputSize = focusedSource.getViewportOutputSize(focusedState);
            if any(outputSize < estimator.MinimumPatchSize)
                result = anchor.LocalRegistrationEstimator.createResult( ...
                    initialNonFocusedState, [0 0], [0 0], 0, outputSize);
                return
            end

            focusedPatch = focusedSource.renderViewport(focusedState, outputSize);
            nonFocusedPatch = nonFocusedSource.renderViewport( ...
                initialNonFocusedState, outputSize);

            [patchShift, peakValue] = ...
                anchor.LocalRegistrationEstimator.estimatePatchShift( ...
                focusedPatch, nonFocusedPatch);

            imageResolution = [ ...
                initialNonFocusedState.getWidth() / outputSize(2), ...
                initialNonFocusedState.getHeight() / outputSize(1)];
            imageShift = -patchShift .* imageResolution;
            targetState = initialNonFocusedState.translate(imageShift);

            result = anchor.LocalRegistrationEstimator.createResult( ...
                targetState, patchShift, imageShift, peakValue, outputSize);
        end
    end

    methods (Static)
        function [patchShift, peakValue] = estimatePatchShift(referencePatch, movingPatch)
            referencePatch = anchor.LocalRegistrationEstimator.preparePatch(referencePatch);
            movingPatch = anchor.LocalRegistrationEstimator.preparePatch(movingPatch);

            if any(size(referencePatch) ~= size(movingPatch)) || ...
                    min(size(referencePatch)) < 2 || ...
                    norm(referencePatch(:)) < eps || norm(movingPatch(:)) < eps
                patchShift = [0 0];
                peakValue = 0;
                return
            end

            crossPower = fft2(referencePatch) .* conj(fft2(movingPatch));
            crossPowerMagnitude = abs(crossPower);
            validBins = crossPowerMagnitude > eps;

            if ~any(validBins, "all")
                patchShift = [0 0];
                peakValue = 0;
                return
            end

            crossPower(validBins) = crossPower(validBins) ./ crossPowerMagnitude(validBins);
            crossPower(~validBins) = 0;

            correlationSurface = real(ifft2(crossPower));
            [peakValue, peakIndex] = max(correlationSurface, [], "all");
            [peakRow, peakCol] = ind2sub(size(correlationSurface), peakIndex);

            nRows = size(correlationSurface, 1);
            nCols = size(correlationSurface, 2);
            xShift = anchor.LocalRegistrationEstimator.signedPeakOffset( ...
                peakCol, nCols) + ...
                anchor.LocalRegistrationEstimator.subpixelPeakOffset( ...
                correlationSurface(peakRow, :), peakCol);
            yShift = anchor.LocalRegistrationEstimator.signedPeakOffset( ...
                peakRow, nRows) + ...
                anchor.LocalRegistrationEstimator.subpixelPeakOffset( ...
                correlationSurface(:, peakCol).', peakRow);

            patchShift = [xShift, yShift];
        end
    end

    methods (Access = private, Static)
        function patch = preparePatch(patch)
            patch = double(patch);
            finiteMask = isfinite(patch);

            if ~any(finiteMask, "all")
                patch = zeros(size(patch));
                return
            end

            fillValue = mean(patch(finiteMask), "all");
            patch(~finiteMask) = fillValue;
            patch = patch - mean(patch, "all");
        end

        function offset = signedPeakOffset(peakSubscript, dimensionLength)
            offset = peakSubscript - 1;
            if offset > dimensionLength / 2
                offset = offset - dimensionLength;
            end
        end

        function offset = subpixelPeakOffset(values, peakIndex)
            nValues = numel(values);
            previousIndex = mod(peakIndex - 2, nValues) + 1;
            nextIndex = mod(peakIndex, nValues) + 1;

            leftValue = values(previousIndex);
            centerValue = values(peakIndex);
            rightValue = values(nextIndex);
            denominator = leftValue - 2 * centerValue + rightValue;

            if abs(denominator) < eps
                offset = 0;
                return
            end

            offset = 0.5 * (leftValue - rightValue) / denominator;
            offset = min(max(offset, -0.5), 0.5);
        end

        function result = createResult(targetState, patchShift, imageShift, ...
                peakValue, outputSize)
            result = struct( ...
                "TargetViewportState", targetState, ...
                "PatchShift", patchShift, ...
                "ImageShift", imageShift, ...
                "PeakValue", peakValue, ...
                "OutputSize", outputSize);
        end
    end
end
