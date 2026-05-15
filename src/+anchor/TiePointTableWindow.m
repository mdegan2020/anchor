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
        SaveSessionButton
        LoadSessionButton
        Table
    end

    properties
        AddTiePointRequestedFcn = []
        DeleteTiePointRequestedFcn = []
        TiePointSelectedFcn = []
        TiePointEditedFcn = []
        MatchAFromBRequestedFcn = []
        MatchBFromARequestedFcn = []
        SaveSessionRequestedFcn = []
        LoadSessionRequestedFcn = []
        CloseRequestedFcn = []
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

        function setTiePoints(window, tiePoints, activeId)
            window.Table.Data = anchor.TiePointTableWindow.formatTiePointTable(tiePoints);
            if height(tiePoints) == 0
                window.Table.ColumnEditable = false(1, 7);
            else
                window.Table.ColumnEditable = [false true true true true true true];
            end
            window.DeleteButton.Enable = anchor.TiePointTableWindow.onOff(~isnan(activeId));

            if ~isnan(activeId)
                rowIndex = find(tiePoints.Id == activeId, 1);
                if ~isempty(rowIndex) && isprop(window.Table, "Selection")
                    window.Table.Selection = [rowIndex 1];
                end
            end
        end

        function choice = confirmUnsavedCsvClose(window, outputPath)
            if ~window.isOpen()
                choice = "Save and Close";
                return
            end

            message = sprintf([ ...
                "The tiepoint CSV has changes that have not been saved to:\n\n%s\n\n" ...
                "Save before closing ANCHOR?"], char(outputPath));

            choice = string(uiconfirm(window.UIFigure, message, ...
                "Unsaved CSV Changes", ...
                "Options", ["Save and Close", "Close Without Saving", "Cancel"], ...
                "DefaultOption", "Save and Close", ...
                "CancelOption", "Cancel"));
        end

        function alertCsvSaveFailed(window, message)
            if ~window.isOpen()
                return
            end

            if strlength(message) == 0
                message = "The tiepoint CSV could not be written.";
            end

            uialert(window.UIFigure, message, "CSV Save Failed");
        end
    end

    methods (Access = private)
        function createComponents(window)
            window.UIFigure = uifigure( ...
                "Name", window.WindowTitle, ...
                "Position", window.InitialPosition, ...
                "CloseRequestFcn", @(~, ~) window.handleCloseRequest(), ...
                "WindowKeyPressFcn", @(~, event) window.handleKeyPress(event));

            window.GridLayout = uigridlayout(window.UIFigure, [2 1]);
            window.GridLayout.RowHeight = {"fit", "1x"};
            window.GridLayout.ColumnWidth = {"1x"};
            window.GridLayout.Padding = [10 10 10 10];
            window.GridLayout.RowSpacing = 8;

            window.ToolbarGrid = uigridlayout(window.GridLayout, [1 7]);
            window.ToolbarGrid.Layout.Row = 1;
            window.ToolbarGrid.Layout.Column = 1;
            window.ToolbarGrid.ColumnWidth = {"fit", "fit", "fit", "fit", "fit", "fit", "1x"};
            window.ToolbarGrid.RowHeight = {"fit"};
            window.ToolbarGrid.Padding = [0 0 0 0];
            window.ToolbarGrid.ColumnSpacing = 8;

            window.AddButton = uibutton(window.ToolbarGrid, ...
                "Text", "Add Centered Point", ...
                "ButtonPushedFcn", @(~, ~) window.requestAddTiePoint());
            window.AddButton.Layout.Row = 1;
            window.AddButton.Layout.Column = 1;

            window.DeleteButton = uibutton(window.ToolbarGrid, ...
                "Text", "Delete", ...
                "Enable", "off", ...
                "ButtonPushedFcn", @(~, ~) window.requestDeleteTiePoint());
            window.DeleteButton.Layout.Row = 1;
            window.DeleteButton.Layout.Column = 2;

            window.MatchAButton = uibutton(window.ToolbarGrid, ...
                "Text", "A from B", ...
                "ButtonPushedFcn", @(~, ~) window.requestMatchAFromB());
            window.MatchAButton.Layout.Row = 1;
            window.MatchAButton.Layout.Column = 3;

            window.MatchBButton = uibutton(window.ToolbarGrid, ...
                "Text", "B from A", ...
                "ButtonPushedFcn", @(~, ~) window.requestMatchBFromA());
            window.MatchBButton.Layout.Row = 1;
            window.MatchBButton.Layout.Column = 4;

            window.SaveSessionButton = uibutton(window.ToolbarGrid, ...
                "Text", "Save Session", ...
                "ButtonPushedFcn", @(~, ~) window.requestSaveSession());
            window.SaveSessionButton.Layout.Row = 1;
            window.SaveSessionButton.Layout.Column = 5;

            window.LoadSessionButton = uibutton(window.ToolbarGrid, ...
                "Text", "Load Session", ...
                "ButtonPushedFcn", @(~, ~) window.requestLoadSession());
            window.LoadSessionButton.Layout.Row = 1;
            window.LoadSessionButton.Layout.Column = 6;

            window.Table = uitable(window.GridLayout);
            window.Table.Layout.Row = 2;
            window.Table.Layout.Column = 1;
            window.Table.Data = anchor.TiePointTableWindow.emptyTiePointTable();
            window.Table.ColumnEditable = false(1, 7);
            window.Table.ColumnWidth = {70, 90, 90, 90, 90, 80, "auto"};
            window.Table.CellSelectionCallback = @(~, event) window.handleCellSelection(event);
            window.Table.CellEditCallback = @(~, event) window.handleCellEdit(event);
        end

        function handleCellSelection(window, event)
            if isempty(event.Indices)
                return
            end

            rowIndex = event.Indices(1);
            data = window.Table.Data;
            if rowIndex < 1 || rowIndex > height(data)
                return
            end

            window.invokeCallback(window.TiePointSelectedFcn, data.Id(rowIndex));
        end

        function handleCellEdit(window, event)
            if isempty(event.Indices)
                return
            end

            rowIndex = event.Indices(1);
            columnIndex = event.Indices(2);
            data = window.Table.Data;
            if rowIndex < 1 || rowIndex > height(data)
                return
            end

            fieldNames = string(data.Properties.VariableNames);
            if columnIndex < 1 || columnIndex > numel(fieldNames)
                return
            end
            fieldName = fieldNames(columnIndex);

            if any(fieldName == ["A_X", "A_Y", "B_X", "B_Y"])
                value = str2double(string(event.NewData));
                if ~isfinite(value)
                    window.restoreEditedCell(rowIndex, fieldName, event.PreviousData);
                    return
                end
            else
                value = event.NewData;
            end

            window.invokeCallback(window.TiePointEditedFcn, ...
                data.Id(rowIndex), fieldName, value);
        end

        function handleKeyPress(window, event)
            if string(event.Key) == "backspace"
                window.requestDeleteTiePoint();
            end
        end

        function handleCloseRequest(window)
            if isempty(window.CloseRequestedFcn)
                delete(window);
            else
                window.invokeCallback(window.CloseRequestedFcn);
            end
        end

        function requestAddTiePoint(window)
            window.invokeCallback(window.AddTiePointRequestedFcn);
        end

        function requestDeleteTiePoint(window)
            window.invokeCallback(window.DeleteTiePointRequestedFcn);
        end

        function requestMatchAFromB(window)
            window.invokeCallback(window.MatchAFromBRequestedFcn);
        end

        function requestMatchBFromA(window)
            window.invokeCallback(window.MatchBFromARequestedFcn);
        end

        function requestSaveSession(window)
            window.invokeCallback(window.SaveSessionRequestedFcn);
        end

        function requestLoadSession(window)
            window.invokeCallback(window.LoadSessionRequestedFcn);
        end

        function restoreEditedCell(window, rowIndex, fieldName, previousData)
            data = window.Table.Data;
            data.(fieldName)(rowIndex) = string(previousData);
            window.Table.Data = data;
        end
    end

    methods (Access = private, Static)
        function data = emptyTiePointTable()
            data = table( ...
                "Size", [0 7], ...
                "VariableTypes", ["double", "double", "double", "double", "double", "logical", "string"], ...
                "VariableNames", ["Id", "A_X", "A_Y", "B_X", "B_Y", "Enabled", "Notes"]);
        end

        function data = formatTiePointTable(tiePoints)
            data = tiePoints;
            data.A_X = anchor.TiePointTableWindow.formatCoordinateColumn(tiePoints.A_X);
            data.A_Y = anchor.TiePointTableWindow.formatCoordinateColumn(tiePoints.A_Y);
            data.B_X = anchor.TiePointTableWindow.formatCoordinateColumn(tiePoints.B_X);
            data.B_Y = anchor.TiePointTableWindow.formatCoordinateColumn(tiePoints.B_Y);
        end

        function values = formatCoordinateColumn(values)
            formattedValues = strings(size(values));
            for index = 1:numel(values)
                formattedValues(index) = ...
                    anchor.TiePointTableWindow.formatCoordinate(values(index));
            end
            values = formattedValues;
        end

        function text = formatCoordinate(value)
            text = string(sprintf("%.10f", value));
            text = regexprep(text, "(\.\d*?)0+$", "$1");
            text = regexprep(text, "\.$", "");
        end

        function invokeCallback(callback, varargin)
            if ~isempty(callback)
                callback(varargin{:});
            end
        end

        function value = onOff(tf)
            if tf
                value = "on";
            else
                value = "off";
            end
        end
    end
end
