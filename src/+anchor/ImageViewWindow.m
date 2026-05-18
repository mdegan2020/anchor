classdef ImageViewWindow < handle
    %ImageViewWindow Floating single-image display window for ANCHOR.

    properties (Access = private)
        ImageSource
        ImageRole (1, 1) string
        WindowTitle (1, 1) string
        InitialPosition (1, 4) double

        UIFigure
        GridLayout
        HeaderGrid
        RoleLabel
        SizeLabel
        FitButton
        Axes
        ImageHandle
        MarkerHandles = gobjects(0)
        DragTiePointId double = NaN
        LastMarkerDoubleClickTime (1, 1) datetime = NaT
        IsPanning (1, 1) logical = false
        PanStartPoint (1, 2) double = [NaN NaN]
        CrosshairVisible (1, 1) logical = false
        CrosshairHandles = gobjects(0)
        OverlayHandle = gobjects(0)
        OverlayBaseXData (1, 2) double = [NaN NaN]
        OverlayBaseYData (1, 2) double = [NaN NaN]
        OverlayOffset (1, 2) double = [0 0]
        OverlayAlpha (1, 1) double = 0.5
        OverlayTimer = []
        IsOverlayDragging (1, 1) logical = false
        OverlayDragStartPoint (1, 2) double = [NaN NaN]
        OverlayDragStartOffset (1, 2) double = [0 0]
    end

    properties
        CenteredTiePointRequestedFcn = []
        TiePointSelectedFcn = []
        MarkerMovedFcn = []
        MarkerDoubleClickedFcn = []
        KeyPressedFcn = []
        KeyReleasedFcn = []
        MouseWheelFcn = []
        FocusGainedFcn = []
        CloseRequestedFcn = []
    end

    methods
        function window = ImageViewWindow(imageSource, imageRole, windowTitle, initialPosition)
            arguments
                imageSource anchor.MatrixImageSource
                imageRole (1, 1) string
                windowTitle (1, 1) string
                initialPosition (1, 4) double = [100 100 640 520]
            end

            window.ImageSource = imageSource;
            window.ImageRole = imageRole;
            window.WindowTitle = windowTitle;
            window.InitialPosition = initialPosition;

            window.createComponents();
            window.renderImage();
        end

        function delete(window)
            window.stopOverlayTimer();
            if ~isempty(window.UIFigure) && isvalid(window.UIFigure)
                window.UIFigure.CloseRequestFcn = [];
                delete(window.UIFigure);
            end
        end

        function tf = isOpen(window)
            tf = ~isempty(window.UIFigure) && isvalid(window.UIFigure);
        end

        function name = getWindowName(window)
            if window.isOpen()
                name = string(window.UIFigure.Name);
            else
                name = window.WindowTitle;
            end
        end

        function position = getWindowPosition(window)
            if window.isOpen()
                position = window.UIFigure.Position;
            else
                position = window.InitialPosition;
            end
        end

        function role = getImageRole(window)
            role = window.ImageRole;
        end

        function center = getViewCenter(window)
            center = [mean(window.Axes.XLim), mean(window.Axes.YLim)];
        end

        function state = getViewportState(window)
            state = anchor.ViewportState(window.Axes.XLim, window.Axes.YLim);
        end

        function setViewportState(window, state)
            window.setLimits(state.XLim, state.YLim);
        end

        function centerOnPoint(window, point)
            xWidth = diff(window.Axes.XLim);
            yHeight = diff(window.Axes.YLim);
            window.setCenteredLimits(point, xWidth, yHeight);
        end

        function zoomAtPoint(window, anchorPoint, zoomFactor)
            oldXLim = window.Axes.XLim;
            oldYLim = window.Axes.YLim;
            oldWidth = diff(oldXLim);
            oldHeight = diff(oldYLim);

            anchorPoint = window.clampPoint(anchorPoint);
            xFraction = (anchorPoint(1) - oldXLim(1)) / oldWidth;
            yFraction = (anchorPoint(2) - oldYLim(1)) / oldHeight;
            xFraction = min(max(xFraction, 0), 1);
            yFraction = min(max(yFraction, 0), 1);

            newWidth = oldWidth * zoomFactor;
            newHeight = oldHeight * zoomFactor;
            xLimits = [ ...
                anchorPoint(1) - xFraction * newWidth, ...
                anchorPoint(1) + (1 - xFraction) * newWidth];
            yLimits = [ ...
                anchorPoint(2) - yFraction * newHeight, ...
                anchorPoint(2) + (1 - yFraction) * newHeight];

            window.setLimits(xLimits, yLimits);
        end

        function fitToImage(window)
            imageSize = window.ImageSource.getImageSize();
            window.setLimits([0.5, imageSize(2) + 0.5], [0.5, imageSize(1) + 0.5]);
        end

        function toggleCrosshair(window)
            window.CrosshairVisible = ~window.CrosshairVisible;
            window.updateCrosshair();
        end

        function bringToFront(window)
            if window.isOpen()
                figure(window.UIFigure);
                drawnow;
            end
        end

        function showTranslatedOverlay(window, imageSource, offset, alpha, shouldFlicker)
            arguments
                window
                imageSource anchor.MatrixImageSource
                offset (1, 2) double
                alpha (1, 1) double = 0.5
                shouldFlicker (1, 1) logical = false
            end

            window.hideOverlay();

            viewport = window.getViewportState();
            sourceViewport = viewport.translate(-offset);
            outputSize = window.getOverlayOutputSize(viewport);
            imageData = imageSource.renderViewport(sourceViewport, outputSize);

            window.OverlayBaseXData = viewport.XLim;
            window.OverlayBaseYData = viewport.YLim;
            window.OverlayOffset = [0 0];
            window.OverlayAlpha = min(max(alpha, 0), 1);

            hold(window.Axes, "on");
            window.OverlayHandle = image(window.Axes, ...
                "XData", window.OverlayBaseXData, ...
                "YData", window.OverlayBaseYData, ...
                "CData", imageData, ...
                "AlphaData", window.OverlayAlpha, ...
                "HitTest", "off", ...
                "PickableParts", "none");
            hold(window.Axes, "off");
            colormap(window.Axes, gray(256));

            if shouldFlicker
                window.startOverlayTimer();
            end
        end

        function hideOverlay(window)
            window.stopOverlayTimer();
            if ~isempty(window.OverlayHandle) && isvalid(window.OverlayHandle)
                delete(window.OverlayHandle);
            end
            window.OverlayHandle = gobjects(0);
            window.OverlayOffset = [0 0];
            window.IsOverlayDragging = false;
        end

        function tf = hasOverlay(window)
            tf = ~isempty(window.OverlayHandle) && isvalid(window.OverlayHandle);
        end

        function offset = getOverlayOffset(window)
            offset = window.OverlayOffset;
        end

        function adjustOverlayAlpha(window, delta)
            window.OverlayAlpha = min(max(window.OverlayAlpha + delta, 0.05), 1.0);
            if window.hasOverlay()
                window.OverlayHandle.AlphaData = window.OverlayAlpha;
            end
        end

        function setTiePoints(window, tiePoints, activeId)
            window.clearMarkers();

            for rowIndex = 1:height(tiePoints)
                id = tiePoints.Id(rowIndex);
                if window.ImageRole == "A"
                    point = [tiePoints.A_X(rowIndex), tiePoints.A_Y(rowIndex)];
                else
                    point = [tiePoints.B_X(rowIndex), tiePoints.B_Y(rowIndex)];
                end

                isActive = id == activeId;
                isEnabled = tiePoints.Enabled(rowIndex);
                window.addMarker(id, point, isActive, isEnabled);
            end
        end
    end

    methods (Access = private)
        function createComponents(window)
            window.UIFigure = uifigure( ...
                "Name", window.WindowTitle, ...
                "Position", window.InitialPosition, ...
                "CloseRequestFcn", @(~, ~) window.handleCloseRequest(), ...
                "WindowKeyPressFcn", @(~, event) window.handleKeyPress(event), ...
                "WindowKeyReleaseFcn", @(~, event) window.handleKeyRelease(event), ...
                "WindowButtonDownFcn", @(~, ~) window.handleWindowButtonDown(), ...
                "WindowButtonMotionFcn", @(~, ~) window.handleWindowButtonMotion(), ...
                "WindowButtonUpFcn", @(~, ~) window.handleWindowButtonUp(), ...
                "WindowScrollWheelFcn", @(~, event) window.handleMouseWheel(event));

            window.GridLayout = uigridlayout(window.UIFigure, [2 1]);
            window.GridLayout.RowHeight = {"fit", "1x"};
            window.GridLayout.ColumnWidth = {"1x"};
            window.GridLayout.Padding = [10 10 10 10];
            window.GridLayout.RowSpacing = 8;

            window.HeaderGrid = uigridlayout(window.GridLayout, [1 3]);
            window.HeaderGrid.Layout.Row = 1;
            window.HeaderGrid.Layout.Column = 1;
            window.HeaderGrid.ColumnWidth = {"1x", "fit", "fit"};
            window.HeaderGrid.RowHeight = {"fit"};
            window.HeaderGrid.Padding = [0 0 0 0];
            window.HeaderGrid.ColumnSpacing = 8;

            window.RoleLabel = uilabel(window.HeaderGrid, ...
                "Text", "Image " + window.ImageRole, ...
                "FontWeight", "bold");
            window.RoleLabel.Layout.Row = 1;
            window.RoleLabel.Layout.Column = 1;

            imageSize = window.ImageSource.getImageSize();
            window.SizeLabel = uilabel(window.HeaderGrid, ...
                "Text", sprintf("%d x %d", imageSize(2), imageSize(1)), ...
                "HorizontalAlignment", "right");
            window.SizeLabel.Layout.Row = 1;
            window.SizeLabel.Layout.Column = 2;

            window.FitButton = uibutton(window.HeaderGrid, ...
                "Text", "Fit", ...
                "ButtonPushedFcn", @(~, ~) window.fitToImage());
            window.FitButton.Layout.Row = 1;
            window.FitButton.Layout.Column = 3;

            window.Axes = uiaxes(window.GridLayout);
            window.Axes.Layout.Row = 2;
            window.Axes.Layout.Column = 1;
            window.Axes.Box = "on";
            window.Axes.Toolbar.Visible = "on";
            window.Axes.XLabel.String = "Column (x)";
            window.Axes.YLabel.String = "Row (y)";
        end

        function renderImage(window)
            imageData = window.ImageSource.getDisplayData();
            window.ImageHandle = imagesc(window.Axes, imageData);
            window.ImageHandle.HitTest = "off";

            colormap(window.Axes, gray(256));
            window.Axes.CLim = window.ImageSource.getDisplayLimits();
            window.Axes.YDir = "reverse";
            axis(window.Axes, "image");

            imageSize = window.ImageSource.getImageSize();
            window.setLimits([0.5, imageSize(2) + 0.5], [0.5, imageSize(1) + 0.5]);
            title(window.Axes, window.ImageSource.Name, "Interpreter", "none");
        end

        function addMarker(window, id, point, isActive, isEnabled)
            if ~isEnabled
                markerColor = [1.0 0.1 0.1];
            elseif isActive
                markerColor = [1.0 0.85 0.1];
            else
                markerColor = [0.1 0.8 1.0];
            end

            if isActive
                markerSize = 12;
                lineWidth = 2.0;
            else
                markerSize = 9;
                lineWidth = 1.5;
            end

            hold(window.Axes, "on");
            circleMarker = plot(window.Axes, point(1), point(2), "o", ...
                "MarkerSize", markerSize, ...
                "LineWidth", lineWidth, ...
                "MarkerFaceColor", "none", ...
                "MarkerEdgeColor", markerColor, ...
                "UserData", id, ...
                "ButtonDownFcn", @(src, ~) window.handleMarkerMouseDown(src));
            xMarker = plot(window.Axes, point(1), point(2), "x", ...
                "MarkerSize", markerSize + 2, ...
                "LineWidth", lineWidth, ...
                "MarkerEdgeColor", markerColor, ...
                "UserData", id, ...
                "ButtonDownFcn", @(src, ~) window.handleMarkerMouseDown(src));
            hold(window.Axes, "off");

            window.MarkerHandles = [window.MarkerHandles circleMarker xMarker];
        end

        function clearMarkers(window)
            validMarkers = window.MarkerHandles(isvalid(window.MarkerHandles));
            delete(validMarkers);
            window.MarkerHandles = gobjects(0);
        end

        function handleMarkerMouseDown(window, marker)
            window.invokeCallback(window.FocusGainedFcn);

            id = marker.UserData;
            selectionType = string(window.UIFigure.SelectionType);
            window.invokeCallback(window.TiePointSelectedFcn, id);

            if selectionType == "open"
                window.LastMarkerDoubleClickTime = datetime("now");
                window.invokeCallback(window.MarkerDoubleClickedFcn, id);
                return
            end

            window.DragTiePointId = id;
        end

        function handleWindowButtonDown(window)
            window.invokeCallback(window.FocusGainedFcn);
            selectionType = string(window.UIFigure.SelectionType);

            if selectionType == "open"
                if ~isnat(window.LastMarkerDoubleClickTime) && ...
                        seconds(datetime("now") - window.LastMarkerDoubleClickTime) < 0.25
                    window.LastMarkerDoubleClickTime = NaT;
                    return
                end

                point = window.getCurrentAxesPoint();
                if window.isPointInsideView(point)
                    window.centerOnPoint(point);
                end
                return
            end

            if ~isnan(window.DragTiePointId) || selectionType ~= "normal"
                if window.hasOverlay() && selectionType == "alt"
                    window.startOverlayDrag();
                end
                return
            end

            point = window.getCurrentAxesPoint();
            if ~window.isPointInsideView(point)
                return
            end

            window.IsPanning = true;
            window.PanStartPoint = point;
        end

        function handleWindowButtonMotion(window)
            if isnan(window.DragTiePointId)
                if window.IsOverlayDragging
                    currentPoint = window.getCurrentImagePoint();
                    delta = currentPoint - window.OverlayDragStartPoint;
                    window.setOverlayOffset(window.OverlayDragStartOffset + delta);
                    return
                end

                if window.IsPanning
                    currentPoint = window.getCurrentAxesPoint();
                    delta = currentPoint - window.PanStartPoint;
                    window.setLimits(window.Axes.XLim - delta(1), ...
                        window.Axes.YLim - delta(2));
                    drawnow limitrate
                end
                return
            end

            point = window.getCurrentImagePoint();
            window.invokeCallback(window.MarkerMovedFcn, window.DragTiePointId, point);
        end

        function handleWindowButtonUp(window)
            window.DragTiePointId = NaN;
            window.IsPanning = false;
            window.IsOverlayDragging = false;
        end

        function handleKeyPress(window, event)
            window.invokeCallback(window.FocusGainedFcn);
            window.invokeCallback(window.KeyPressedFcn, string(event.Key), string(event.Modifier));
        end

        function handleKeyRelease(window, event)
            window.invokeCallback(window.KeyReleasedFcn, string(event.Key), string(event.Modifier));
        end

        function handleCloseRequest(window)
            if isempty(window.CloseRequestedFcn)
                delete(window);
            else
                window.invokeCallback(window.CloseRequestedFcn);
            end
        end

        function handleMouseWheel(window, event)
            window.invokeCallback(window.FocusGainedFcn);
            modifiers = strings(1, 0);
            if isprop(event, "Modifier")
                modifiers = string(event.Modifier);
            end

            handled = window.invokeCallbackWithOutput( ...
                window.MouseWheelFcn, false, event.VerticalScrollCount, modifiers);
            if handled
                return
            end

            anchorPoint = window.getCurrentAxesPoint();
            if ~window.isPointInsideView(anchorPoint)
                return
            end

            zoomFactor = 1.2 ^ event.VerticalScrollCount;
            window.zoomAtPoint(anchorPoint, zoomFactor);
        end

        function point = getCurrentImagePoint(window)
            point = window.clampPoint(window.getCurrentAxesPoint());
        end

        function point = getCurrentAxesPoint(window)
            currentPoint = window.Axes.CurrentPoint;
            point = currentPoint(1, 1:2);
        end

        function point = clampPoint(window, point)
            imageSize = window.ImageSource.getImageSize();
            point(1) = min(max(point(1), 1), imageSize(2));
            point(2) = min(max(point(2), 1), imageSize(1));
        end

        function setCenteredLimits(window, point, xWidth, yHeight)
            imageSize = window.ImageSource.getImageSize();
            point = window.clampPoint(point);

            xWidth = min(max(xWidth, 1), imageSize(2));
            yHeight = min(max(yHeight, 1), imageSize(1));

            halfWidth = xWidth / 2;
            halfHeight = yHeight / 2;

            xLimits = [point(1) - halfWidth, point(1) + halfWidth];
            yLimits = [point(2) - halfHeight, point(2) + halfHeight];

            window.setLimits(xLimits, yLimits);
        end

        function setLimits(window, xLimits, yLimits)
            imageSize = window.ImageSource.getImageSize();
            xLimits = sort(xLimits);
            yLimits = sort(yLimits);

            if diff(xLimits) >= imageSize(2)
                xLimits = [0.5, imageSize(2) + 0.5];
            end
            if diff(yLimits) >= imageSize(1)
                yLimits = [0.5, imageSize(1) + 0.5];
            end

            if xLimits(1) < 0.5
                xLimits = xLimits + (0.5 - xLimits(1));
            end
            if xLimits(2) > imageSize(2) + 0.5
                xLimits = xLimits - (xLimits(2) - imageSize(2) - 0.5);
            end
            if yLimits(1) < 0.5
                yLimits = yLimits + (0.5 - yLimits(1));
            end
            if yLimits(2) > imageSize(1) + 0.5
                yLimits = yLimits - (yLimits(2) - imageSize(1) - 0.5);
            end

            window.Axes.XLim = xLimits;
            window.Axes.YLim = yLimits;
            window.updateCrosshair();
        end

        function tf = isPointInsideView(window, point)
            tf = point(1) >= window.Axes.XLim(1) && point(1) <= window.Axes.XLim(2) && ...
                point(2) >= window.Axes.YLim(1) && point(2) <= window.Axes.YLim(2);
        end

        function updateCrosshair(window)
            validHandles = window.CrosshairHandles(isvalid(window.CrosshairHandles));

            if ~window.CrosshairVisible
                delete(validHandles);
                window.CrosshairHandles = gobjects(0);
                return
            end

            center = window.getViewCenter();
            if numel(validHandles) ~= 2
                delete(validHandles);
                hold(window.Axes, "on");
                horizontal = plot(window.Axes, window.Axes.XLim, [center(2) center(2)], ...
                    "y-", "LineWidth", 0.8, "HitTest", "off", "PickableParts", "none");
                vertical = plot(window.Axes, [center(1) center(1)], window.Axes.YLim, ...
                    "y-", "LineWidth", 0.8, "HitTest", "off", "PickableParts", "none");
                hold(window.Axes, "off");
                window.CrosshairHandles = [horizontal vertical];
                return
            end

            validHandles(1).XData = window.Axes.XLim;
            validHandles(1).YData = [center(2) center(2)];
            validHandles(2).XData = [center(1) center(1)];
            validHandles(2).YData = window.Axes.YLim;
        end

        function startOverlayDrag(window)
            window.IsOverlayDragging = true;
            window.OverlayDragStartPoint = window.getCurrentImagePoint();
            window.OverlayDragStartOffset = window.OverlayOffset;
        end

        function setOverlayOffset(window, offset)
            window.OverlayOffset = offset;

            if window.hasOverlay()
                window.OverlayHandle.XData = window.OverlayBaseXData + offset(1);
                window.OverlayHandle.YData = window.OverlayBaseYData + offset(2);
            end
        end

        function outputSize = getOverlayOutputSize(window, viewport)
            axesPosition = window.Axes.Position;
            displaySize = max(2, round([axesPosition(4), axesPosition(3)]));
            viewportSize = [ ...
                max(2, round(viewport.getHeight())), ...
                max(2, round(viewport.getWidth()))];
            outputSize = min(viewportSize, displaySize);
        end

        function startOverlayTimer(window)
            window.stopOverlayTimer();

            window.OverlayTimer = timer( ...
                "ExecutionMode", "fixedSpacing", ...
                "Period", 0.35, ...
                "TimerFcn", @(~, ~) window.toggleOverlayVisibility());
            start(window.OverlayTimer);
        end

        function stopOverlayTimer(window)
            if ~isempty(window.OverlayTimer) && isvalid(window.OverlayTimer)
                stop(window.OverlayTimer);
                delete(window.OverlayTimer);
            end
            window.OverlayTimer = [];
        end

        function toggleOverlayVisibility(window)
            if window.hasOverlay()
                if window.OverlayHandle.Visible == "on"
                    window.OverlayHandle.Visible = "off";
                else
                    window.OverlayHandle.Visible = "on";
                end
            end
        end
    end

    methods (Access = private, Static)
        function invokeCallback(callback, varargin)
            if ~isempty(callback)
                callback(varargin{:});
            end
        end

        function output = invokeCallbackWithOutput(callback, defaultOutput, varargin)
            if isempty(callback)
                output = defaultOutput;
            else
                output = callback(varargin{:});
                if isempty(output)
                    output = defaultOutput;
                end
            end
        end
    end
end
