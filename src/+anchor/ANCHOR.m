classdef ANCHOR < handle
    %ANCHOR Top-level coordinator for the ANCHOR tiepoint application.

    properties (Access = private)
        ImageSourceA
        ImageSourceB
        ImageWindowA
        ImageWindowB
        TableWindow
    end

    methods
        function app = ANCHOR(imageA, imageB)
            if nargin == 0
                [imageA, imageB] = anchor.ANCHOR.createDemoImages();
            elseif nargin ~= 2
                error("anchor:ANCHOR:InvalidInput", ...
                    "ANCHOR expects either zero inputs or two image inputs.");
            end

            app.ImageSourceA = anchor.ANCHOR.asImageSource(imageA, "Image A");
            app.ImageSourceB = anchor.ANCHOR.asImageSource(imageB, "Image B");

            positions = anchor.ANCHOR.defaultWindowPositions();

            app.TableWindow = anchor.TiePointTableWindow( ...
                "ANCHOR Tiepoints", positions.Table);

            app.ImageWindowA = anchor.ImageViewWindow( ...
                app.ImageSourceA, "A", "ANCHOR Image A", positions.ImageA);

            app.ImageWindowB = anchor.ImageViewWindow( ...
                app.ImageSourceB, "B", "ANCHOR Image B", positions.ImageB);
        end

        function delete(app)
            anchor.ANCHOR.deleteIfValid(app.ImageWindowA);
            anchor.ANCHOR.deleteIfValid(app.ImageWindowB);
            anchor.ANCHOR.deleteIfValid(app.TableWindow);
        end

        function count = getWindowCount(app)
            count = 0;
            if anchor.ANCHOR.isOpen(app.TableWindow)
                count = count + 1;
            end
            if anchor.ANCHOR.isOpen(app.ImageWindowA)
                count = count + 1;
            end
            if anchor.ANCHOR.isOpen(app.ImageWindowB)
                count = count + 1;
            end
        end

        function names = getWindowNames(app)
            names = strings(1, 0);
            if anchor.ANCHOR.isOpen(app.TableWindow)
                names(end + 1) = app.TableWindow.getWindowName();
            end
            if anchor.ANCHOR.isOpen(app.ImageWindowA)
                names(end + 1) = app.ImageWindowA.getWindowName();
            end
            if anchor.ANCHOR.isOpen(app.ImageWindowB)
                names(end + 1) = app.ImageWindowB.getWindowName();
            end
        end
    end

    methods (Access = private, Static)
        function source = asImageSource(inputImage, defaultName)
            if isa(inputImage, "anchor.MatrixImageSource")
                source = inputImage;
                return
            end

            if isnumeric(inputImage)
                source = anchor.MatrixImageSource(inputImage, defaultName);
                return
            end

            error("anchor:ANCHOR:UnsupportedImageInput", ...
                "Image inputs must be numeric matrices or anchor.MatrixImageSource instances.");
        end

        function [imageA, imageB] = createDemoImages()
            nRows = 512;
            nCols = 640;
            [x, y] = meshgrid(linspace(-3, 3, nCols), linspace(-2.5, 2.5, nRows));

            base = 0.45 * sin(2.4 * x) + 0.30 * cos(3.1 * y);
            base = base + 1.3 * exp(-2.0 * ((x + 1.2).^2 + (y - 0.6).^2));
            base = base + 0.9 * exp(-3.2 * ((x - 1.1).^2 + (y + 0.8).^2));
            base = base + 0.2 * x + 0.1 * y;
            base = base - min(base, [], "all");
            imageA = base ./ max(base, [], "all");

            texture = 0.035 * sin(8 * x + 1.5) .* cos(5 * y - 0.5);
            imageB = min(max(imageA.^0.95 + texture, 0), 1);
        end

        function positions = defaultWindowPositions()
            screen = get(groot, "ScreenSize");
            margin = 50;
            gap = 30;
            tableHeight = 280;

            availableWidth = max(900, screen(3) - 2 * margin);
            imageWidth = min(640, floor((availableWidth - gap) / 2));
            imageHeight = min(520, max(360, screen(4) - tableHeight - 3 * margin - gap));
            tableWidth = min(760, availableWidth);

            imageY = margin;
            tableY = min(screen(4) - tableHeight - margin, imageY + imageHeight + gap);
            imageAX = margin;
            imageBX = imageAX + imageWidth + gap;

            positions = struct( ...
                "Table", [margin, tableY, tableWidth, tableHeight], ...
                "ImageA", [imageAX, imageY, imageWidth, imageHeight], ...
                "ImageB", [imageBX, imageY, imageWidth, imageHeight]);
        end

        function tf = isOpen(window)
            tf = ~isempty(window) && isvalid(window) && window.isOpen();
        end

        function deleteIfValid(window)
            if ~isempty(window) && isvalid(window)
                delete(window);
            end
        end
    end
end
