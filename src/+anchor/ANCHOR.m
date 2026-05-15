classdef ANCHOR < handle
    %ANCHOR Top-level coordinator for the ANCHOR tiepoint application.

    properties (Access = private)
        ImageSourceA
        ImageSourceB
        TiePointStore
        HomographyModel
        CsvWriter
        ImageWindowA
        ImageWindowB
        TableWindow
        ActiveImageRole (1, 1) string = "A"
        OverlayMode (1, 1) string = "none"
        OverlayFocusedRole (1, 1) string = "A"
        OverlayOtherRole (1, 1) string = "B"
        OverlayTiePointId double = NaN
        OverlayAlpha (1, 1) double = 0.5
        IsClosing (1, 1) logical = false
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
            app.TiePointStore = anchor.TiePointStore();
            app.HomographyModel = anchor.HomographyModel();
            app.CsvWriter = anchor.CsvTiePointWriter();

            positions = anchor.ANCHOR.defaultWindowPositions();

            app.TableWindow = anchor.TiePointTableWindow( ...
                "ANCHOR Tiepoints", positions.Table);

            app.ImageWindowA = anchor.ImageViewWindow( ...
                app.ImageSourceA, "A", "ANCHOR Image A", positions.ImageA);

            app.ImageWindowB = anchor.ImageViewWindow( ...
                app.ImageSourceB, "B", "ANCHOR Image B", positions.ImageB);

            app.wireCallbacks();
            app.refreshTiePointViews();
        end

        function delete(app)
            if ~app.IsClosing
                app.writeCsvIfReady();
            end
            app.IsClosing = true;

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

        function count = getTiePointCount(app)
            count = app.TiePointStore.getCount();
        end

        function id = getActiveTiePointId(app)
            id = app.TiePointStore.getActiveId();
        end

        function outputPath = getCsvOutputPath(app)
            outputPath = app.CsvWriter.OutputPath;
        end

        function id = createTiePointAtViewCenters(app)
            id = app.createCenteredTiePoint();
        end

        function deleteActiveTiePoint(app)
            app.deleteActiveTiePointInternal();
        end

        function data = getTiePointTable(app)
            data = app.TiePointStore.toTable();
        end

        function transformType = getTransformType(app)
            transformType = app.HomographyModel.TransformType;
        end

        function matchImageAViewFromB(app)
            app.matchView("B", "A");
        end

        function matchImageBViewFromA(app)
            app.matchView("A", "B");
        end

        function imageRole = getActiveImageRole(app)
            imageRole = app.ActiveImageRole;
        end
    end

    methods (Access = private)
        function wireCallbacks(app)
            app.TableWindow.AddTiePointRequestedFcn = @() app.createCenteredTiePoint();
            app.TableWindow.DeleteTiePointRequestedFcn = @() app.deleteActiveTiePointInternal();
            app.TableWindow.TiePointSelectedFcn = @(id) app.selectTiePoint(id);
            app.TableWindow.TiePointEditedFcn = @(id, fieldName, value) ...
                app.updateTiePointField(id, fieldName, value);
            app.TableWindow.MatchAFromBRequestedFcn = @() app.matchImageAViewFromB();
            app.TableWindow.MatchBFromARequestedFcn = @() app.matchImageBViewFromA();
            app.TableWindow.CloseRequestedFcn = @() app.closeApplication();

            app.ImageWindowA.CenteredTiePointRequestedFcn = @() app.createCenteredTiePoint();
            app.ImageWindowB.CenteredTiePointRequestedFcn = @() app.createCenteredTiePoint();

            app.ImageWindowA.TiePointSelectedFcn = @(id) app.selectTiePoint(id);
            app.ImageWindowB.TiePointSelectedFcn = @(id) app.selectTiePoint(id);

            app.ImageWindowA.MarkerMovedFcn = @(id, point) app.updateTiePoint("A", id, point);
            app.ImageWindowB.MarkerMovedFcn = @(id, point) app.updateTiePoint("B", id, point);

            app.ImageWindowA.MarkerDoubleClickedFcn = @(id) app.centerOtherWindowOnTiePoint("A", id);
            app.ImageWindowB.MarkerDoubleClickedFcn = @(id) app.centerOtherWindowOnTiePoint("B", id);

            app.ImageWindowA.KeyPressedFcn = @(key, modifiers) app.handleImageKey("A", key, modifiers);
            app.ImageWindowB.KeyPressedFcn = @(key, modifiers) app.handleImageKey("B", key, modifiers);
            app.ImageWindowA.KeyReleasedFcn = @(key, modifiers) app.handleImageKeyRelease("A", key, modifiers);
            app.ImageWindowB.KeyReleasedFcn = @(key, modifiers) app.handleImageKeyRelease("B", key, modifiers);

            app.ImageWindowA.FocusGainedFcn = @() app.setActiveImageRole("A");
            app.ImageWindowB.FocusGainedFcn = @() app.setActiveImageRole("B");

            app.ImageWindowA.CloseRequestedFcn = @() app.closeApplication();
            app.ImageWindowB.CloseRequestedFcn = @() app.closeApplication();
        end

        function id = createCenteredTiePoint(app)
            pointA = app.ImageWindowA.getViewCenter();
            pointB = app.ImageWindowB.getViewCenter();
            id = app.TiePointStore.createTiePoint(pointA, pointB);
            app.persistAndRefresh();
        end

        function deleteActiveTiePointInternal(app)
            app.TiePointStore.deleteActive();
            app.persistAndRefresh();
        end

        function selectTiePoint(app, id)
            app.TiePointStore.selectTiePoint(id);
            app.refreshTiePointViews();
        end

        function updateTiePoint(app, imageRole, id, point)
            app.TiePointStore.updatePoint(id, imageRole, point);
            app.TiePointStore.selectTiePoint(id);
            app.persistAndRefresh();
        end

        function updateTiePointField(app, id, fieldName, value)
            app.TiePointStore.updateField(id, fieldName, value);
            app.persistAndRefresh();
        end

        function handleImageKey(app, imageRole, key, modifiers)
            app.setActiveImageRole(imageRole);
            key = lower(key);
            modifiers = lower(modifiers);

            switch key
                case "shift"
                    app.startOverlay(imageRole, "flicker");
                case "control"
                    app.startOverlay(imageRole, "transparent");
                case "space"
                    app.createCenteredTiePoint();
                case "backspace"
                    app.deleteActiveTiePointInternal();
                case "w"
                    app.nudgeActivePoint(imageRole, [0 -1]);
                case "a"
                    app.nudgeActivePoint(imageRole, [-1 0]);
                case "s"
                    app.nudgeActivePoint(imageRole, [0 1]);
                case "d"
                    app.nudgeActivePoint(imageRole, [1 0]);
                case "f"
                    app.toggleImageFocus(imageRole);
                case "c"
                    app.getImageWindow(imageRole).toggleCrosshair();
                case {"add", "equal", "plus"}
                    if any(modifiers == "control") || app.OverlayMode == "transparent"
                        app.adjustOverlayAlpha(0.05);
                    end
                case {"subtract", "hyphen", "minus"}
                    if any(modifiers == "control") || app.OverlayMode == "transparent"
                        app.adjustOverlayAlpha(-0.05);
                    end
                case "q"
                    app.TiePointStore.selectPrevious();
                    app.centerWindowsOnActiveTiePoint();
                    app.refreshTiePointViews();
                case "e"
                    app.TiePointStore.selectNext();
                    app.centerWindowsOnActiveTiePoint();
                    app.refreshTiePointViews();
            end
        end

        function handleImageKeyRelease(app, imageRole, key, ~)
            app.setActiveImageRole(imageRole);
            key = lower(key);

            switch key
                case "shift"
                    app.endFlickerOverlay();
                case "control"
                    app.commitTransparentOverlay();
            end
        end

        function nudgeActivePoint(app, imageRole, delta)
            app.TiePointStore.nudgeActivePoint(imageRole, delta);
            app.persistAndRefresh();
        end

        function centerWindowsOnActiveTiePoint(app)
            id = app.TiePointStore.getActiveId();
            if isnan(id)
                return
            end

            app.ImageWindowA.centerOnPoint(app.TiePointStore.getPoint(id, "A"));
            app.ImageWindowB.centerOnPoint(app.TiePointStore.getPoint(id, "B"));
        end

        function centerOtherWindowOnTiePoint(app, sourceRole, id)
            app.TiePointStore.selectTiePoint(id);

            if sourceRole == "A"
                app.ImageWindowB.centerOnPoint(app.TiePointStore.getPoint(id, "B"));
            else
                app.ImageWindowA.centerOnPoint(app.TiePointStore.getPoint(id, "A"));
            end

            app.refreshTiePointViews();
        end

        function setActiveImageRole(app, imageRole)
            app.ActiveImageRole = imageRole;
        end

        function persistAndRefresh(app)
            app.updateHomography();
            app.writeCsvIfReady();
            app.refreshTiePointViews();
        end

        function updateHomography(app)
            app.HomographyModel.update(app.TiePointStore.toTable());
        end

        function writeCsvIfReady(app)
            if isempty(app.CsvWriter) || isempty(app.TiePointStore) || ...
                    isempty(app.ImageSourceA) || isempty(app.ImageSourceB)
                return
            end

            app.CsvWriter.write(app.TiePointStore.toTable(), app.ImageSourceA, app.ImageSourceB);
        end

        function closeApplication(app)
            if app.IsClosing
                return
            end

            app.IsClosing = true;
            app.writeCsvIfReady();
            delete(app);
        end

        function matchView(app, sourceRole, targetRole)
            sourceWindow = app.getImageWindow(sourceRole);
            targetWindow = app.getImageWindow(targetRole);
            targetState = app.HomographyModel.mapViewport( ...
                sourceWindow.getViewportState(), sourceRole, targetRole);
            targetWindow.setViewportState(targetState);
        end

        function toggleImageFocus(app, sourceRole)
            if sourceRole == "A"
                targetRole = "B";
            else
                targetRole = "A";
            end

            app.setActiveImageRole(targetRole);
            app.getImageWindow(targetRole).bringToFront();
        end

        function startOverlay(app, focusedRole, mode)
            id = app.TiePointStore.getActiveId();
            if isnan(id)
                return
            end

            otherRole = app.otherImageRole(focusedRole);
            focusedPoint = app.TiePointStore.getPoint(id, focusedRole);
            otherPoint = app.TiePointStore.getPoint(id, otherRole);
            if any(isnan([focusedPoint otherPoint]))
                return
            end

            focusedWindow = app.getImageWindow(focusedRole);
            otherSource = app.getImageSource(otherRole);
            offset = focusedPoint - otherPoint;
            shouldFlicker = mode == "flicker";

            app.ImageWindowA.hideOverlay();
            app.ImageWindowB.hideOverlay();
            focusedWindow.showTranslatedOverlay( ...
                otherSource.getDisplayData(), offset, app.OverlayAlpha, shouldFlicker);

            app.OverlayMode = mode;
            app.OverlayFocusedRole = focusedRole;
            app.OverlayOtherRole = otherRole;
            app.OverlayTiePointId = id;
        end

        function endFlickerOverlay(app)
            if app.OverlayMode ~= "flicker"
                return
            end

            app.getImageWindow(app.OverlayFocusedRole).hideOverlay();
            app.clearOverlayState();
        end

        function commitTransparentOverlay(app)
            if app.OverlayMode ~= "transparent"
                return
            end

            focusedWindow = app.getImageWindow(app.OverlayFocusedRole);
            overlayDelta = focusedWindow.getOverlayOffset();
            focusedWindow.hideOverlay();

            if ~isnan(app.OverlayTiePointId)
                oldOtherPoint = app.TiePointStore.getPoint(app.OverlayTiePointId, app.OverlayOtherRole);
                newOtherPoint = oldOtherPoint - overlayDelta;
                app.TiePointStore.updatePoint(app.OverlayTiePointId, app.OverlayOtherRole, newOtherPoint);
                app.TiePointStore.selectTiePoint(app.OverlayTiePointId);
                app.persistAndRefresh();
            end

            app.clearOverlayState();
        end

        function adjustOverlayAlpha(app, delta)
            app.OverlayAlpha = min(max(app.OverlayAlpha + delta, 0.05), 1.0);

            if app.OverlayMode == "transparent"
                app.getImageWindow(app.OverlayFocusedRole).adjustOverlayAlpha(delta);
            end
        end

        function clearOverlayState(app)
            app.OverlayMode = "none";
            app.OverlayTiePointId = NaN;
        end

        function refreshTiePointViews(app)
            tiePoints = app.TiePointStore.toTable();
            activeId = app.TiePointStore.getActiveId();

            app.TableWindow.setTiePoints(tiePoints, activeId);
            app.ImageWindowA.setTiePoints(tiePoints, activeId);
            app.ImageWindowB.setTiePoints(tiePoints, activeId);
        end

        function window = getImageWindow(app, imageRole)
            if imageRole == "A"
                window = app.ImageWindowA;
            elseif imageRole == "B"
                window = app.ImageWindowB;
            else
                error("anchor:ANCHOR:InvalidImageRole", ...
                    "Image role must be ""A"" or ""B"".");
            end
        end

        function source = getImageSource(app, imageRole)
            if imageRole == "A"
                source = app.ImageSourceA;
            elseif imageRole == "B"
                source = app.ImageSourceB;
            else
                error("anchor:ANCHOR:InvalidImageRole", ...
                    "Image role must be ""A"" or ""B"".");
            end
        end
    end

    methods (Access = private, Static)
        function otherRole = otherImageRole(imageRole)
            if imageRole == "A"
                otherRole = "B";
            elseif imageRole == "B"
                otherRole = "A";
            else
                error("anchor:ANCHOR:InvalidImageRole", ...
                    "Image role must be ""A"" or ""B"".");
            end
        end

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
