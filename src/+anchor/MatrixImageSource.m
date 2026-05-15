classdef MatrixImageSource < handle
    %MatrixImageSource In-memory single-channel image source.

    properties (SetAccess = private)
        Data
        Name (1, 1) string
    end

    methods
        function source = MatrixImageSource(data, name)
            if nargin < 2
                name = "Matrix image";
            end

            validateattributes(data, {'numeric'}, {'2d', 'nonempty'}, ...
                'anchor.MatrixImageSource', 'data');

            source.Data = data;
            source.Name = string(name);
        end

        function imageSize = getImageSize(source)
            imageSize = size(source.Data);
        end

        function displayData = getDisplayData(source)
            displayData = source.Data;
        end

        function state = toSessionStruct(source)
            state = struct( ...
                "Type", "MatrixImageSource", ...
                "Name", source.Name, ...
                "Data", source.Data);
        end

        function outputSize = getViewportOutputSize(~, viewportState)
            outputSize = [ ...
                max(1, round(viewportState.getHeight())), ...
                max(1, round(viewportState.getWidth()))];
        end

        function patch = renderViewport(source, viewportState, outputSize)
            arguments
                source
                viewportState anchor.ViewportState
                outputSize (1, 2) double {mustBeInteger, mustBePositive}
            end

            nRows = outputSize(1);
            nCols = outputSize(2);
            xSamples = anchor.MatrixImageSource.sampleCenters( ...
                viewportState.XLim, nCols);
            ySamples = anchor.MatrixImageSource.sampleCenters( ...
                viewportState.YLim, nRows);
            [xGrid, yGrid] = meshgrid(xSamples, ySamples);

            patch = interp2(double(source.Data), xGrid, yGrid, "linear", NaN);
        end

        function limits = getDisplayLimits(source)
            finiteData = double(source.Data(isfinite(source.Data)));

            if isempty(finiteData)
                limits = [0 1];
                return
            end

            low = min(finiteData, [], "all");
            high = max(finiteData, [], "all");

            if low == high
                low = low - 0.5;
                high = high + 0.5;
            end

            limits = [low high];
        end
    end

    methods (Access = private, Static)
        function samples = sampleCenters(limits, count)
            width = diff(limits);
            sampleSpacing = width / count;
            if count == 1
                samples = mean(limits);
                return
            end

            samples = linspace( ...
                limits(1) + sampleSpacing / 2, ...
                limits(2) - sampleSpacing / 2, ...
                count);
        end
    end

    methods (Static)
        function source = fromSessionStruct(state)
            if ~isfield(state, "Type") || string(state.Type) ~= "MatrixImageSource"
                error("anchor:MatrixImageSource:InvalidSessionState", ...
                    "Session image source state is not a MatrixImageSource.");
            end

            source = anchor.MatrixImageSource(state.Data, string(state.Name));
        end
    end
end
