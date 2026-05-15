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
    end

    methods (Access = private)
        function createComponents(window)
            window.UIFigure = uifigure( ...
                "Name", window.WindowTitle, ...
                "Position", window.InitialPosition, ...
                "CloseRequestFcn", @(~, ~) delete(window));

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
    end
end
