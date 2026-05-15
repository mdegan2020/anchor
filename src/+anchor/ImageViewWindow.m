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
        Axes
        ImageHandle
        MarkerHandles = gobjects(0)
        DragTiePointId double = NaN
    end

    properties
        CenteredTiePointRequestedFcn = []
        TiePointSelectedFcn = []
        MarkerMovedFcn = []
        MarkerDoubleClickedFcn = []
        KeyPressedFcn = []
        FocusGainedFcn = []
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

        function centerOnPoint(window, point)
            xWidth = diff(window.Axes.XLim);
            yHeight = diff(window.Axes.YLim);
            window.setCenteredLimits(point, xWidth, yHeight);
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
                "CloseRequestFcn", @(~, ~) delete(window), ...
                "WindowKeyPressFcn", @(~, event) window.handleKeyPress(event), ...
                "WindowButtonDownFcn", @(~, ~) window.handleWindowButtonDown(), ...
                "WindowButtonMotionFcn", @(~, ~) window.handleWindowButtonMotion(), ...
                "WindowButtonUpFcn", @(~, ~) window.handleWindowButtonUp());

            window.GridLayout = uigridlayout(window.UIFigure, [2 1]);
            window.GridLayout.RowHeight = {"fit", "1x"};
            window.GridLayout.ColumnWidth = {"1x"};
            window.GridLayout.Padding = [10 10 10 10];
            window.GridLayout.RowSpacing = 8;

            window.HeaderGrid = uigridlayout(window.GridLayout, [1 2]);
            window.HeaderGrid.Layout.Row = 1;
            window.HeaderGrid.Layout.Column = 1;
            window.HeaderGrid.ColumnWidth = {"1x", "fit"};
            window.HeaderGrid.RowHeight = {"fit"};
            window.HeaderGrid.Padding = [0 0 0 0];

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
            window.Axes.XLim = [0.5, imageSize(2) + 0.5];
            window.Axes.YLim = [0.5, imageSize(1) + 0.5];
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
            marker = plot(window.Axes, point(1), point(2), "o", ...
                "MarkerSize", markerSize, ...
                "LineWidth", lineWidth, ...
                "MarkerFaceColor", markerColor, ...
                "MarkerEdgeColor", "k", ...
                "UserData", id, ...
                "ButtonDownFcn", @(src, ~) window.handleMarkerMouseDown(src));
            hold(window.Axes, "off");

            window.MarkerHandles(end + 1) = marker;
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
        end

        function handleWindowButtonMotion(window)
            if isnan(window.DragTiePointId)
                return
            end

            point = window.getCurrentImagePoint();
            window.invokeCallback(window.MarkerMovedFcn, window.DragTiePointId, point);
        end

        function handleWindowButtonUp(window)
            window.DragTiePointId = NaN;
        end

        function handleKeyPress(window, event)
            window.invokeCallback(window.FocusGainedFcn);
            window.invokeCallback(window.KeyPressedFcn, string(event.Key));
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

            halfWidth = xWidth / 2;
            halfHeight = yHeight / 2;

            xLimits = [point(1) - halfWidth, point(1) + halfWidth];
            yLimits = [point(2) - halfHeight, point(2) + halfHeight];

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
