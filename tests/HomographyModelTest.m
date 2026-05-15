classdef HomographyModelTest < matlab.unittest.TestCase
    %HomographyModelTest Tests homography fitting behavior.

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            srcFolder = fullfile(fileparts(fileparts(mfilename("fullpath"))), "src");
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(srcFolder));
        end
    end

    methods (Test)
        function updateExcludesDisabledTiepoints(testCase)
            tiePoints = table( ...
                [1; 2; 3], ...
                [0; 10; 20], ...
                [0; 0; 0], ...
                [10; 20; 1000], ...
                [20; 20; 1000], ...
                [true; true; false], ...
                ["one"; "two"; "disabled"], ...
                VariableNames=["Id", "A_X", "A_Y", "B_X", "B_Y", "Enabled", "Notes"]);
            model = anchor.HomographyModel();

            model.update(tiePoints);
            mappedPoint = model.mapPoints([5 5], "A", "B");

            testCase.verifyEqual(model.TransformType, "shift");
            testCase.verifyEqual(mappedPoint, [15 25], AbsTol=1e-12);
        end
    end
end
