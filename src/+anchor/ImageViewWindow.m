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
        IsPanning (1, 1) logical = false
        PanStartPoint (1, 2) double = [NaN NaN]
        PanStartXLim (1, 2) double = [NaN NaN]
        PanStartYLim (1, 2) double = [NaN NaN]
        CrosshairVisible (1, 1) logical = false
        CrosshairHandles = gobjects(0)
    end

    properties
        CenteredTiePointRequestedFcn = []
        TiePointSelectedFcn = []
        MarkerMovedFcn = []
        MarkerDoubleClickedFcn = []
        KeyPressedFcn = []
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
                window.addMarker(id, point, isActive);
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

        function addMarker(window, id, point, isActive)
            if isActive
                markerColor = [1.0 0.85 0.1];
                markerSize = 12;
                lineWidth = 2.0;
            else
                markerColor = [0.1 0.8 1.0];
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
                window.invokeCallback(window.MarkerDoubleClickedFcn, id);
                return
            end

            window.DragTiePointId = id;
        end

        function handleWindowButtonDown(window)
            window.invokeCallback(window.FocusGainedFcn);

            if ~isnan(window.DragTiePointId) || string(window.UIFigure.SelectionType) ~= "normal"
                return
            end

            point = window.getCurrentImagePoint();
            if ~window.isPointInsideView(point)
                return
            end

            window.IsPanning = true;
            window.PanStartPoint = point;
            window.PanStartXLim = window.Axes.XLim;
            window.PanStartYLim = window.Axes.YLim;
        end

        function handleWindowButtonMotion(window)
            if isnan(window.DragTiePointId)
                if window.IsPanning
                    currentPoint = window.getCurrentImagePoint();
                    delta = currentPoint - window.PanStartPoint;
                    window.setLimits(window.PanStartXLim - delta(1), ...
                        window.PanStartYLim - delta(2));
                end
                return
            end

            point = window.getCurrentImagePoint();
            window.invokeCallback(window.MarkerMovedFcn, window.DragTiePointId, point);
        end

        function handleWindowButtonUp(window)
            window.DragTiePointId = NaN;
            window.IsPanning = false;
        end

        function handleKeyPress(window, event)
            window.invokeCallback(window.FocusGainedFcn);
            window.invokeCallback(window.KeyPressedFcn, string(event.Key));
        end

        function handleCloseRequest(window)
            if isempty(window.CloseRequestedFcn)
                delete(window);
            else
                window.invokeCallback(window.CloseRequestedFcn);
            end
        end

        function handleMouseWheel(window, event)
            anchorPoint = window.getCurrentImagePoint();
            zoomFactor = 1.2 ^ event.VerticalScrollCount;
            newWidth = diff(window.Axes.XLim) * zoomFactor;
            newHeight = diff(window.Axes.YLim) * zoomFactor;

            window.setCenteredLimits(anchorPoint, newWidth, newHeight);
        end

        function point = getCurrentImagePoint(window)
            currentPoint = window.Axes.CurrentPoint;
            point = currentPoint(1, 1:2);
            point = window.clampPoint(point);
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
    end

    methods (Access = private, Static)
        function invokeCallback(callback, varargin)
            if ~isempty(callback)
                callback(varargin{:});
            end
        end
    end
end
