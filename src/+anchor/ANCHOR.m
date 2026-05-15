classdef ANCHOR < handle
    %ANCHOR Top-level coordinator for the ANCHOR tiepoint application.

    properties (Access = private)
        ImageSourceA
        ImageSourceB
        TiePointStore
        HomographyModel
        LocalRegistrationEstimator
        CsvWriter
        SessionPath (1, 1) string = ""
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
        function app = ANCHOR(imageA, imageB, csvOutputPath)
            if nargin == 0
                [imageA, imageB] = anchor.ANCHOR.createDemoImages();
                csvOutputPath = "";
            elseif nargin == 2
                csvOutputPath = "";
            elseif nargin ~= 3
                error("anchor:ANCHOR:InvalidInput", ...
                    "ANCHOR expects zero inputs, two image inputs, or two image inputs and a CSV output path.");
            end

            app.ImageSourceA = anchor.ANCHOR.asImageSource(imageA, "Image A");
            app.ImageSourceB = anchor.ANCHOR.asImageSource(imageB, "Image B");
            app.TiePointStore = anchor.TiePointStore();
            app.HomographyModel = anchor.HomographyModel();
            app.LocalRegistrationEstimator = anchor.LocalRegistrationEstimator();
            app.CsvWriter = anchor.ANCHOR.createCsvWriter(csvOutputPath);

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

        function result = alignOtherViewByLocalCorrelation(app, focusedRole)
            if nargin < 2
                focusedRole = app.ActiveImageRole;
            end

            result = app.alignOtherViewByLocalCorrelationInternal(string(focusedRole));
        end

        function saveSession(app, sessionPath)
            arguments
                app
                sessionPath (1, 1) string
            end

            anchor.SessionSerializer.saveSession(sessionPath, app.createSessionStruct());
            app.SessionPath = sessionPath;
        end

        function loadSession(app, sessionPath)
            arguments
                app
                sessionPath (1, 1) string
            end

            session = anchor.SessionSerializer.loadSession(sessionPath);
            app.applySessionStruct(session);
            app.SessionPath = sessionPath;
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
            app.TableWindow.SaveSessionRequestedFcn = @() app.saveSessionFromDialog();
            app.TableWindow.LoadSessionRequestedFcn = @() app.loadSessionFromDialog();
            app.TableWindow.CloseRequestedFcn = @() app.closeApplication("table");

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

            app.ImageWindowA.CloseRequestedFcn = @() app.closeApplication("image");
            app.ImageWindowB.CloseRequestedFcn = @() app.closeApplication("image");
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
                case "g"
                    app.alignOtherViewByLocalCorrelationInternal(imageRole);
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
            app.markCsvDirty();
            app.writeCsvIfReady();
            app.refreshTiePointViews();
        end

        function updateHomography(app)
            app.HomographyModel.update(app.TiePointStore.toTable());
        end

        function markCsvDirty(app)
            if ~isempty(app.CsvWriter)
                app.CsvWriter.markDirty();
            end
        end

        function writeCsvIfReady(app)
            if isempty(app.CsvWriter) || isempty(app.TiePointStore) || ...
                    isempty(app.ImageSourceA) || isempty(app.ImageSourceB)
                return
            end

            try
                app.CsvWriter.write(app.TiePointStore.toTable(), app.ImageSourceA, app.ImageSourceB);
            catch err
                warning("anchor:ANCHOR:CsvWriteFailed", ...
                    "Unable to write tiepoint CSV '%s': %s", ...
                    char(app.CsvWriter.OutputPath), err.message);
            end
        end

        function closeApplication(app, closeSource)
            if nargin < 2
                closeSource = "controller";
            end

            if app.IsClosing
                return
            end

            writeOnClose = true;
            if closeSource == "table"
                [shouldClose, writeOnClose] = app.confirmTableClose();
                if ~shouldClose
                    return
                end
            end

            app.IsClosing = true;
            if writeOnClose
                app.writeCsvIfReady();
            end
            delete(app);
        end

        function [shouldClose, writeOnClose] = confirmTableClose(app)
            shouldClose = true;
            writeOnClose = true;

            if isempty(app.CsvWriter) || ~app.CsvWriter.HasUnsavedChanges
                return
            end

            choice = app.TableWindow.confirmUnsavedCsvClose(app.CsvWriter.OutputPath);
            switch choice
                case "Save and Close"
                    app.writeCsvIfReady();
                    writeOnClose = false;
                    if app.CsvWriter.HasUnsavedChanges
                        app.TableWindow.alertCsvSaveFailed(app.CsvWriter.LastErrorMessage);
                        shouldClose = false;
                    end
                case "Close Without Saving"
                    writeOnClose = false;
                otherwise
                    shouldClose = false;
                    writeOnClose = false;
            end
        end

        function matchView(app, sourceRole, targetRole)
            sourceWindow = app.getImageWindow(sourceRole);
            targetWindow = app.getImageWindow(targetRole);
            targetState = app.HomographyModel.mapViewport( ...
                sourceWindow.getViewportState(), sourceRole, targetRole);
            targetWindow.setViewportState(targetState);
        end

        function saveSessionFromDialog(app)
            defaultPath = app.defaultSessionDialogPath();
            [fileName, folderName] = uiputfile("*.mat", ...
                "Save ANCHOR Session", defaultPath);
            if isequal(fileName, 0) || isequal(folderName, 0)
                return
            end

            app.saveSession(fullfile(folderName, fileName));
        end

        function loadSessionFromDialog(app)
            [fileName, folderName] = uigetfile("*.mat", "Load ANCHOR Session");
            if isequal(fileName, 0) || isequal(folderName, 0)
                return
            end

            app.loadSession(fullfile(folderName, fileName));
        end

        function sessionPath = defaultSessionDialogPath(app)
            if strlength(app.SessionPath) > 0
                sessionPath = app.SessionPath;
            else
                sessionPath = fullfile(pwd, "anchor_session.mat");
            end
        end

        function session = createSessionStruct(app)
            session = struct( ...
                "Version", "1.0", ...
                "CreatedAt", string(datetime("now")), ...
                "ImageA", app.ImageSourceA.toSessionStruct(), ...
                "ImageB", app.ImageSourceB.toSessionStruct(), ...
                "TiePoints", app.TiePointStore.toTable(), ...
                "ActiveTiePointId", app.TiePointStore.getActiveId(), ...
                "Homography", app.HomographyModel.toSessionStruct(), ...
                "CsvOutputPath", app.CsvWriter.OutputPath, ...
                "ViewportA", app.viewportToStruct(app.ImageWindowA.getViewportState()), ...
                "ViewportB", app.viewportToStruct(app.ImageWindowB.getViewportState()), ...
                "ActiveImageRole", app.ActiveImageRole);
        end

        function applySessionStruct(app, session)
            app.ImageSourceA = anchor.MatrixImageSource.fromSessionStruct(session.ImageA);
            app.ImageSourceB = anchor.MatrixImageSource.fromSessionStruct(session.ImageB);
            app.TiePointStore.replaceFromTable(session.TiePoints, session.ActiveTiePointId);
            app.HomographyModel.restoreFromSessionStruct(session.Homography);
            app.CsvWriter.setOutputPath(session.CsvOutputPath);
            app.ActiveImageRole = session.ActiveImageRole;
            app.recreateImageWindows();
            app.ImageWindowA.setViewportState(app.structToViewport(session.ViewportA));
            app.ImageWindowB.setViewportState(app.structToViewport(session.ViewportB));
            app.refreshTiePointViews();
            app.writeCsvIfReady();
        end

        function recreateImageWindows(app)
            positionA = app.ImageWindowA.getWindowPosition();
            positionB = app.ImageWindowB.getWindowPosition();

            anchor.ANCHOR.deleteIfValid(app.ImageWindowA);
            anchor.ANCHOR.deleteIfValid(app.ImageWindowB);

            app.ImageWindowA = anchor.ImageViewWindow( ...
                app.ImageSourceA, "A", "ANCHOR Image A", positionA);
            app.ImageWindowB = anchor.ImageViewWindow( ...
                app.ImageSourceB, "B", "ANCHOR Image B", positionB);
            app.wireCallbacks();
        end

        function result = alignOtherViewByLocalCorrelationInternal(app, focusedRole)
            otherRole = app.otherImageRole(focusedRole);
            focusedWindow = app.getImageWindow(focusedRole);
            otherWindow = app.getImageWindow(otherRole);
            focusedState = focusedWindow.getViewportState();
            initialOtherState = app.HomographyModel.mapViewport( ...
                focusedState, focusedRole, otherRole);

            result = app.LocalRegistrationEstimator.estimate( ...
                app.getImageSource(focusedRole), ...
                app.getImageSource(otherRole), ...
                focusedState, ...
                initialOtherState);

            otherWindow.setViewportState(result.TargetViewportState);
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

        function writer = createCsvWriter(csvOutputPath)
            csvOutputPath = string(csvOutputPath);
            if strlength(csvOutputPath) == 0
                writer = anchor.CsvTiePointWriter();
            else
                writer = anchor.CsvTiePointWriter(csvOutputPath);
            end
        end

        function state = viewportToStruct(viewport)
            state = struct("XLim", viewport.XLim, "YLim", viewport.YLim);
        end

        function viewport = structToViewport(state)
            viewport = anchor.ViewportState(state.XLim, state.YLim);
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
