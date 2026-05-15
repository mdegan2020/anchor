classdef CsvTiePointWriter < handle
    %CsvTiePointWriter Continuously writes tiepoint state to CSV.

    properties (SetAccess = private)
        OutputPath (1, 1) string
        HasUnsavedChanges (1, 1) logical = false
        LastErrorMessage (1, 1) string = ""
    end

    methods
        function writer = CsvTiePointWriter(outputPath)
            if nargin < 1 || strlength(string(outputPath)) == 0
                outputPath = fullfile(pwd, "anchor_tiepoints.csv");
            end

            writer.OutputPath = string(outputPath);
        end

        function markDirty(writer)
            writer.HasUnsavedChanges = true;
        end

        function write(writer, tiePoints, sourceA, sourceB)
            outputTable = table( ...
                repmat(sourceA.Name, height(tiePoints), 1), ...
                tiePoints.A_X, tiePoints.A_Y, ...
                repmat(sourceB.Name, height(tiePoints), 1), ...
                tiePoints.B_X, tiePoints.B_Y, ...
                double(tiePoints.Enabled), ...
                'VariableNames', {'fname1', 'ix1', 'iy1', 'fname2', 'ix2', 'iy2', 'enabled'});

            tempPath = writer.OutputPath + ".tmp";
            try
                writetable(outputTable, tempPath, 'FileType', 'text');
                movefile(tempPath, writer.OutputPath, 'f');
                writer.HasUnsavedChanges = false;
                writer.LastErrorMessage = "";
            catch err
                writer.HasUnsavedChanges = true;
                writer.LastErrorMessage = string(err.message);
                rethrow(err);
            end
        end
    end
end
