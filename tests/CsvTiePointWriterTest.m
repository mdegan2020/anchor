classdef CsvTiePointWriterTest < matlab.unittest.TestCase
    %CsvTiePointWriterTest Tests ANCHOR CSV export formatting.

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            srcFolder = fullfile(fileparts(fileparts(mfilename("fullpath"))), "src");
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(srcFolder));
        end
    end

    methods (Test)
        function writeUsesFixedCoordinateNotation(testCase)
            outputPath = string(tempname) + ".csv";
            testCase.addTeardown(@() CsvTiePointWriterTest.deleteFile(outputPath));
            sourceA = anchor.MatrixImageSource(uint8(zeros(4, 4)), "A");
            sourceB = anchor.MatrixImageSource(uint8(ones(4, 4)), "B");
            store = anchor.TiePointStore();
            id = store.createTiePoint([123456789.25 987654321.5], ...
                [1000001.125 2000002.75]);
            store.updateField(id, "Enabled", true);
            writer = anchor.CsvTiePointWriter(outputPath);

            writer.write(store.toTable(), sourceA, sourceB);
            csvText = string(fileread(outputPath));

            testCase.verifyTrue(contains(csvText, "123456789.25"));
            testCase.verifyTrue(contains(csvText, "987654321.5"));
            testCase.verifyTrue(contains(csvText, "1000001.125"));
            testCase.verifyTrue(contains(csvText, "2000002.75"));
            testCase.verifyFalse(contains(csvText, "e+"));
            testCase.verifyFalse(contains(csvText, "E+"));
        end
    end

    methods (Static, Access = private)
        function deleteFile(filePath)
            if isfile(filePath)
                delete(filePath);
            end
        end
    end
end
