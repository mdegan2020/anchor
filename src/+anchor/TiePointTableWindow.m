classdef TiePointTableWindow < handle
    %TiePointTableWindow Floating tiepoint table and control window.

    properties (Access = private)
        WindowTitle (1, 1) string
        InitialPosition (1, 4) double

        UIFigure
        GridLayout
        ToolbarGrid
        AddButton
        DeleteButton
        MatchAButton
        MatchBButton
        Table
    end

    methods
        function window = TiePointTableWindow(windowTitle, initialPosition)
            arguments
                windowTitle (1, 1) string = "ANCHOR Tiepoints"
                initialPosition (1, 4) double = [100 100 720 300]
            end

            window.WindowTitle = windowTitle;
            window.InitialPosition = initialPosition;
            window.createComponents();
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

            window.ToolbarGrid = uigridlayout(window.GridLayout, [1 5]);
            window.ToolbarGrid.Layout.Row = 1;
            window.ToolbarGrid.Layout.Column = 1;
            window.ToolbarGrid.ColumnWidth = {"fit", "fit", "fit", "fit", "1x"};
            window.ToolbarGrid.RowHeight = {"fit"};
            window.ToolbarGrid.Padding = [0 0 0 0];
            window.ToolbarGrid.ColumnSpacing = 8;

            window.AddButton = uibutton(window.ToolbarGrid, ...
                "Text", "Add Centered Point", ...
                "Enable", "off");
            window.AddButton.Layout.Row = 1;
            window.AddButton.Layout.Column = 1;

            window.DeleteButton = uibutton(window.ToolbarGrid, ...
                "Text", "Delete", ...
                "Enable", "off");
            window.DeleteButton.Layout.Row = 1;
            window.DeleteButton.Layout.Column = 2;

            window.MatchAButton = uibutton(window.ToolbarGrid, ...
                "Text", "A from B", ...
                "Enable", "off");
            window.MatchAButton.Layout.Row = 1;
            window.MatchAButton.Layout.Column = 3;

            window.MatchBButton = uibutton(window.ToolbarGrid, ...
                "Text", "B from A", ...
                "Enable", "off");
            window.MatchBButton.Layout.Row = 1;
            window.MatchBButton.Layout.Column = 4;

            window.Table = uitable(window.GridLayout);
            window.Table.Layout.Row = 2;
            window.Table.Layout.Column = 1;
            window.Table.Data = anchor.TiePointTableWindow.emptyTiePointTable();
            window.Table.ColumnEditable = false(1, 7);
            window.Table.ColumnWidth = {70, 90, 90, 90, 90, 80, "auto"};
        end
    end

    methods (Access = private, Static)
        function data = emptyTiePointTable()
            data = table( ...
                "Size", [0 7], ...
                "VariableTypes", ["double", "double", "double", "double", "double", "logical", "string"], ...
                "VariableNames", ["Id", "A_X", "A_Y", "B_X", "B_Y", "Enabled", "Notes"]);
        end
    end
end
