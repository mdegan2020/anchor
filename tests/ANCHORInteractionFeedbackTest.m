classdef ANCHORInteractionFeedbackTest < matlab.unittest.TestCase
    %ANCHORInteractionFeedbackTest Tests recent interaction feedback fixes.

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            srcFolder = fullfile(fileparts(fileparts(mfilename("fullpath"))), "src");
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(srcFolder));
        end
    end

    methods (Test)
        function constructorAcceptsOptionalCsvOutputPath(testCase)
            csvPath = string(tempname) + ".csv";
            testCase.addTeardown(@() ANCHORInteractionFeedbackTest.deleteFile(csvPath));
            app = anchor.ANCHOR(rand(16, 16), rand(16, 16), csvPath);
            testCase.addTeardown(@() ANCHORInteractionFeedbackTest.deleteHandle(app));

            app.createTiePointAtViewCenters();

            testCase.verifyEqual(app.getCsvOutputPath(), csvPath);
            testCase.verifyTrue(isfile(csvPath));
        end

        function zoomAtPointKeepsAnchorAtSameViewFraction(testCase)
            source = anchor.MatrixImageSource(rand(100, 120), "Zoom test");
            window = anchor.ImageViewWindow(source, "A", ...
                "ANCHOR Zoom Test", [100 100 360 300]);
            testCase.addTeardown(@() ANCHORInteractionFeedbackTest.deleteHandle(window));
            window.setViewportState(anchor.ViewportState([10.5 50.5], [20.5 60.5]));
            anchorPoint = [20.5 30.5];
            beforeState = window.getViewportState();
            beforeFraction = ANCHORInteractionFeedbackTest.viewFraction( ...
                beforeState, anchorPoint);

            window.zoomAtPoint(anchorPoint, 0.5);
            afterState = window.getViewportState();
            afterFraction = ANCHORInteractionFeedbackTest.viewFraction( ...
                afterState, anchorPoint);

            testCase.verifyEqual(afterState.getWidth(), 20, AbsTol=1e-12);
            testCase.verifyEqual(afterState.getHeight(), 20, AbsTol=1e-12);
            testCase.verifyEqual(afterFraction, beforeFraction, AbsTol=1e-12);
        end

        function matchOtherViewFromFocusedTransfersViewport(testCase)
            app = anchor.ANCHOR(rand(120, 140), rand(120, 140));
            testCase.addTeardown(@() ANCHORInteractionFeedbackTest.deleteHandle(app));
            testCase.addTeardown(@() ANCHORInteractionFeedbackTest.deleteFile( ...
                fullfile(pwd, "anchor_tiepoints.csv")));
            sourceState = anchor.ViewportState([20.5 70.5], [30.5 80.5]);
            app.setImageViewportState("A", sourceState);
            app.setImageViewportState("B", anchor.ViewportState([1.5 40.5], [1.5 40.5]));

            app.matchOtherViewFromFocused("A");
            targetState = app.getImageViewportState("B");

            testCase.verifyEqual(targetState.XLim, sourceState.XLim, AbsTol=1e-12);
            testCase.verifyEqual(targetState.YLim, sourceState.YLim, AbsTol=1e-12);
        end

        function selectAndCenterTiePointCentersBothViews(testCase)
            app = anchor.ANCHOR(rand(120, 140), rand(120, 140));
            testCase.addTeardown(@() ANCHORInteractionFeedbackTest.deleteHandle(app));
            testCase.addTeardown(@() ANCHORInteractionFeedbackTest.deleteFile( ...
                fullfile(pwd, "anchor_tiepoints.csv")));
            app.setImageViewportState("A", anchor.ViewportState([10.5 40.5], [10.5 40.5]));
            app.setImageViewportState("B", anchor.ViewportState([20.5 50.5], [20.5 50.5]));
            id = app.createTiePointAtViewCenters();
            app.setImageViewportState("A", anchor.ViewportState([70.5 100.5], [70.5 100.5]));
            app.setImageViewportState("B", anchor.ViewportState([80.5 110.5], [80.5 110.5]));

            app.selectAndCenterTiePoint(id);

            testCase.verifyEqual(app.getImageViewportState("A").getCenter(), [25.5 25.5], AbsTol=1e-12);
            testCase.verifyEqual(app.getImageViewportState("B").getCenter(), [35.5 35.5], AbsTol=1e-12);
        end

        function displayTableIncludesDerivedDiagnostics(testCase)
            app = anchor.ANCHOR(rand(120, 140), rand(120, 140));
            testCase.addTeardown(@() ANCHORInteractionFeedbackTest.deleteHandle(app));
            testCase.addTeardown(@() ANCHORInteractionFeedbackTest.deleteFile( ...
                fullfile(pwd, "anchor_tiepoints.csv")));
            id = app.createTiePointAtViewCenters();
            tiePoints = app.getTiePointTable();
            app.setImageViewportState("A", anchor.ViewportState([10.5 40.5], [10.5 40.5]));
            app.setImageViewportState("B", anchor.ViewportState([20.5 50.5], [20.5 50.5]));
            app.createTiePointAtViewCenters();
            app.selectAndCenterTiePoint(id);

            displayTable = app.getTiePointDisplayTable();

            testCase.verifyTrue(all(ismember(["DX", "DY", "Residual"], ...
                string(displayTable.Properties.VariableNames))));
            testCase.verifyEqual(displayTable.DX, displayTable.A_X - displayTable.B_X, AbsTol=1e-12);
            testCase.verifyEqual(displayTable.DY, displayTable.A_Y - displayTable.B_Y, AbsTol=1e-12);
            testCase.verifyEqual(height(displayTable), height(tiePoints) + 1);
        end
    end

    methods (Static, Access = private)
        function fraction = viewFraction(viewportState, point)
            fraction = [ ...
                (point(1) - viewportState.XLim(1)) / viewportState.getWidth(), ...
                (point(2) - viewportState.YLim(1)) / viewportState.getHeight()];
        end

        function deleteFile(filePath)
            if isfile(filePath)
                delete(filePath);
            end
        end

        function deleteHandle(handleObject)
            if isvalid(handleObject)
                delete(handleObject);
            end
        end
    end
end
