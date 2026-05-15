classdef TiePointStore < handle
    %TiePointStore Authoritative complete-pair tiepoint model.

    properties (Access = private)
        Points table
        NextId (1, 1) double = 1
        ActiveId double = NaN
    end

    methods
        function store = TiePointStore()
            store.Points = anchor.TiePointStore.emptyTable();
        end

        function id = createTiePoint(store, imageAPoint, imageBPoint)
            id = store.NextId;
            store.NextId = store.NextId + 1;

            row = table(id, imageAPoint(1), imageAPoint(2), ...
                imageBPoint(1), imageBPoint(2), true, "", ...
                'VariableNames', ["Id", "A_X", "A_Y", "B_X", "B_Y", "Enabled", "Notes"]);

            store.Points = [store.Points; row];
            store.ActiveId = id;
        end

        function tf = hasActiveTiePoint(store)
            tf = ~isnan(store.ActiveId) && any(store.Points.Id == store.ActiveId);
        end

        function id = getActiveId(store)
            id = store.ActiveId;
        end

        function count = getCount(store)
            count = height(store.Points);
        end

        function selectTiePoint(store, id)
            if any(store.Points.Id == id)
                store.ActiveId = id;
            end
        end

        function id = selectByRow(store, row)
            if row >= 1 && row <= height(store.Points)
                id = store.Points.Id(row);
                store.ActiveId = id;
            else
                id = NaN;
            end
        end

        function deleteActive(store)
            if ~store.hasActiveTiePoint()
                return
            end

            rowIndex = find(store.Points.Id == store.ActiveId, 1);
            store.Points(rowIndex, :) = [];

            if isempty(store.Points)
                store.ActiveId = NaN;
            else
                rowIndex = min(rowIndex, height(store.Points));
                store.ActiveId = store.Points.Id(rowIndex);
            end
        end

        function updatePoint(store, id, imageRole, point)
            rowIndex = store.rowIndexForId(id);
            if isempty(rowIndex)
                return
            end

            if imageRole == "A"
                store.Points.A_X(rowIndex) = point(1);
                store.Points.A_Y(rowIndex) = point(2);
            elseif imageRole == "B"
                store.Points.B_X(rowIndex) = point(1);
                store.Points.B_Y(rowIndex) = point(2);
            else
                error("anchor:TiePointStore:InvalidImageRole", ...
                    "Image role must be ""A"" or ""B"".");
            end

            store.ActiveId = id;
        end

        function updateField(store, id, fieldName, value)
            rowIndex = store.rowIndexForId(id);
            if isempty(rowIndex)
                return
            end

            fieldName = string(fieldName);

            switch fieldName
                case {"A_X", "A_Y", "B_X", "B_Y"}
                    validateattributes(value, {'numeric'}, {'scalar', 'finite'}, ...
                        'anchor.TiePointStore.updateField', char(fieldName));
                    store.Points.(fieldName)(rowIndex) = double(value);
                case "Enabled"
                    store.Points.Enabled(rowIndex) = logical(value);
                case "Notes"
                    store.Points.Notes(rowIndex) = string(value);
                otherwise
                    error("anchor:TiePointStore:InvalidField", ...
                        "Unsupported tiepoint field ""%s"".", fieldName);
            end

            store.ActiveId = id;
        end

        function nudgeActivePoint(store, imageRole, delta)
            if ~store.hasActiveTiePoint()
                return
            end

            point = store.getPoint(store.ActiveId, imageRole);
            store.updatePoint(store.ActiveId, imageRole, point + delta);
        end

        function point = getPoint(store, id, imageRole)
            rowIndex = store.rowIndexForId(id);
            if isempty(rowIndex)
                point = [NaN NaN];
                return
            end

            if imageRole == "A"
                point = [store.Points.A_X(rowIndex), store.Points.A_Y(rowIndex)];
            elseif imageRole == "B"
                point = [store.Points.B_X(rowIndex), store.Points.B_Y(rowIndex)];
            else
                error("anchor:TiePointStore:InvalidImageRole", ...
                    "Image role must be ""A"" or ""B"".");
            end
        end

        function selectNext(store)
            store.selectRelative(1);
        end

        function selectPrevious(store)
            store.selectRelative(-1);
        end

        function data = toTable(store)
            data = store.Points;
        end
    end

    methods (Access = private)
        function rowIndex = rowIndexForId(store, id)
            rowIndex = find(store.Points.Id == id, 1);
        end

        function selectRelative(store, step)
            if isempty(store.Points)
                store.ActiveId = NaN;
                return
            end

            if store.hasActiveTiePoint()
                rowIndex = find(store.Points.Id == store.ActiveId, 1);
            else
                rowIndex = 1;
            end

            rowIndex = rowIndex + step;
            rowIndex = max(1, min(height(store.Points), rowIndex));
            store.ActiveId = store.Points.Id(rowIndex);
        end
    end

    methods (Static)
        function data = emptyTable()
            data = table( ...
                'Size', [0 7], ...
                'VariableTypes', {'double', 'double', 'double', 'double', 'double', 'logical', 'string'}, ...
                'VariableNames', {'Id', 'A_X', 'A_Y', 'B_X', 'B_Y', 'Enabled', 'Notes'});
        end
    end
end
