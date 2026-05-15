classdef SessionSerializerTest < matlab.unittest.TestCase
    %SessionSerializerTest Tests ANCHOR session persistence.

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            srcFolder = fullfile(fileparts(fileparts(mfilename("fullpath"))), "src");
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(srcFolder));
        end
    end

    methods (Test)
        function saveLoadRoundTripsSessionStruct(testCase)
            sessionPath = string(tempname) + ".mat";
            testCase.addTeardown(@() SessionSerializerTest.deleteFile(sessionPath));
            session = SessionSerializerTest.createSession();

            anchor.SessionSerializer.saveSession(sessionPath, session);
            restoredSession = anchor.SessionSerializer.loadSession(sessionPath);

            testCase.verifyEqual(restoredSession.Version, "1.0");
            testCase.verifyEqual(restoredSession.ImageA.Data, session.ImageA.Data);
            testCase.verifyEqual(restoredSession.ImageB.Data, session.ImageB.Data);
            testCase.verifyEqual(restoredSession.TiePoints, session.TiePoints);
            testCase.verifyEqual(restoredSession.CsvOutputPath, session.CsvOutputPath);
            testCase.verifyEqual(restoredSession.ViewportA.XLim, session.ViewportA.XLim);
        end

        function appSaveLoadRestoresImagesAndTiepoints(testCase)
            sessionPath = string(tempname) + ".mat";
            testCase.addTeardown(@() SessionSerializerTest.deleteFile(sessionPath));
            testCase.addTeardown(@() SessionSerializerTest.deleteFile( ...
                fullfile(pwd, "anchor_tiepoints.csv")));
            imageA = reshape(uint8(1:100), 10, 10);
            imageB = imageA + 1;
            app = anchor.ANCHOR(imageA, imageB);
            testCase.addTeardown(@() SessionSerializerTest.deleteHandle(app));
            app.createTiePointAtViewCenters();

            app.saveSession(sessionPath);
            restoredApp = anchor.ANCHOR(zeros(6), zeros(6));
            testCase.addTeardown(@() SessionSerializerTest.deleteHandle(restoredApp));
            restoredApp.loadSession(sessionPath);
            restoredApp.saveSession(sessionPath);
            restoredSession = anchor.SessionSerializer.loadSession(sessionPath);

            testCase.verifyEqual(restoredApp.getTiePointCount(), 1);
            testCase.verifyEqual(restoredSession.ImageA.Data, imageA);
            testCase.verifyEqual(restoredSession.ImageB.Data, imageB);
            testCase.verifyEqual(height(restoredSession.TiePoints), 1);
            testCase.verifyEqual(restoredSession.ActiveTiePointId, restoredApp.getActiveTiePointId());
        end
    end

    methods (Static, Access = private)
        function session = createSession()
            sourceA = anchor.MatrixImageSource(uint8(magic(4)), "A");
            sourceB = anchor.MatrixImageSource(uint8(magic(4) + 1), "B");
            store = anchor.TiePointStore();
            activeId = store.createTiePoint([2 3], [4 5]);
            homography = anchor.HomographyModel();
            homography.update(store.toTable());

            session = struct( ...
                "Version", "1.0", ...
                "CreatedAt", "2026-05-15 12:00:00", ...
                "ImageA", sourceA.toSessionStruct(), ...
                "ImageB", sourceB.toSessionStruct(), ...
                "TiePoints", store.toTable(), ...
                "ActiveTiePointId", activeId, ...
                "Homography", homography.toSessionStruct(), ...
                "CsvOutputPath", fullfile(tempdir, "anchor_session_test.csv"), ...
                "ViewportA", struct("XLim", [0.5 4.5], "YLim", [0.5 4.5]), ...
                "ViewportB", struct("XLim", [1.5 5.5], "YLim", [1.5 5.5]), ...
                "ActiveImageRole", "A");
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
