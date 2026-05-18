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

            correlationSurface = normxcorr2(movingPatch, referencePatch);
            [peakValue, peakIndex] = max(correlationSurface, [], "all");
            [peakRow, peakCol] = ind2sub(size(correlationSurface), peakIndex);

            xShift = peakCol - size(movingPatch, 2);
            yShift = peakRow - size(movingPatch, 1);

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
