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
end
