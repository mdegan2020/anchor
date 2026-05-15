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

        function setOutputPath(writer, outputPath)
            arguments
                writer
                outputPath (1, 1) string
            end

            if strlength(outputPath) == 0
                error("anchor:CsvTiePointWriter:InvalidOutputPath", ...
                    "CSV output path must be nonempty.");
            end

            writer.OutputPath = outputPath;
            writer.HasUnsavedChanges = true;
        end

        function write(writer, tiePoints, sourceA, sourceB)
            tempPath = writer.OutputPath + ".tmp";
            try
                writer.writeCsvFile(tempPath, tiePoints, sourceA, sourceB);
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

    methods (Access = private)
        function writeCsvFile(writer, outputPath, tiePoints, sourceA, sourceB)
            fileId = fopen(outputPath, "w");
            if fileId < 0
                error("anchor:CsvTiePointWriter:OpenFailed", ...
                    "Unable to open CSV file '%s' for writing.", outputPath);
            end

            cleanup = onCleanup(@() fclose(fileId));
            fprintf(fileId, "fname1,ix1,iy1,fname2,ix2,iy2,enabled\n");

            for rowIndex = 1:height(tiePoints)
                fprintf(fileId, "%s,%s,%s,%s,%s,%s,%d\n", ...
                    writer.escapeCsvText(sourceA.Name), ...
                    writer.formatCoordinate(tiePoints.A_X(rowIndex)), ...
                    writer.formatCoordinate(tiePoints.A_Y(rowIndex)), ...
                    writer.escapeCsvText(sourceB.Name), ...
                    writer.formatCoordinate(tiePoints.B_X(rowIndex)), ...
                    writer.formatCoordinate(tiePoints.B_Y(rowIndex)), ...
                    tiePoints.Enabled(rowIndex));
            end
        end
    end

    methods (Access = private, Static)
        function text = formatCoordinate(value)
            text = string(sprintf("%.10f", value));
            text = regexprep(text, "(\.\d*?)0+$", "$1");
            text = regexprep(text, "\.$", "");
        end

        function text = escapeCsvText(value)
            text = string(value);
            quote = string('"');

            if contains(text, quote)
                text = replace(text, quote, quote + quote);
            end

            if any(contains(text, [",", newline, char(13)]))
                text = quote + text + quote;
            end
        end
    end
end
