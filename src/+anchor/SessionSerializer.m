classdef SessionSerializer
    %SessionSerializer Reads and writes ANCHOR session MAT files.

    methods (Static)
        function saveSession(sessionPath, session)
            arguments
                sessionPath (1, 1) string
                session struct
            end

            session = anchor.SessionSerializer.normalizeSession(session);
            save(sessionPath, "session", "-mat");
        end

        function session = loadSession(sessionPath)
            arguments
                sessionPath (1, 1) string
            end

            loaded = load(sessionPath, "session", "-mat");
            if ~isfield(loaded, "session")
                error("anchor:SessionSerializer:InvalidSessionFile", ...
                    "Session file does not contain an ANCHOR session.");
            end

            session = anchor.SessionSerializer.normalizeSession(loaded.session);
        end

        function session = normalizeSession(session)
            requiredFields = ["Version", "CreatedAt", "ImageA", "ImageB", ...
                "TiePoints", "ActiveTiePointId", "Homography", ...
                "CsvOutputPath", "ViewportA", "ViewportB", "ActiveImageRole"];
            missingFields = setdiff(requiredFields, string(fieldnames(session)));

            if ~isempty(missingFields)
                error("anchor:SessionSerializer:InvalidSession", ...
                    "Session is missing required fields: %s.", ...
                    strjoin(missingFields, ", "));
            end

            session.Version = string(session.Version);
            session.CreatedAt = string(session.CreatedAt);
            session.ImageA = anchor.SessionSerializer.normalizeImageSourceState(session.ImageA);
            session.ImageB = anchor.SessionSerializer.normalizeImageSourceState(session.ImageB);
            session.TiePoints = anchor.TiePointStore.normalizeTable(session.TiePoints);
            session.ActiveTiePointId = double(session.ActiveTiePointId);
            session.Homography = anchor.SessionSerializer.normalizeHomographyState(session.Homography);
            session.CsvOutputPath = string(session.CsvOutputPath);
            session.ViewportA = anchor.SessionSerializer.normalizeViewportState(session.ViewportA);
            session.ViewportB = anchor.SessionSerializer.normalizeViewportState(session.ViewportB);
            session.ActiveImageRole = string(session.ActiveImageRole);
        end
    end

    methods (Access = private, Static)
        function state = normalizeImageSourceState(state)
            if ~isfield(state, "Type") || ~isfield(state, "Name") || ~isfield(state, "Data")
                error("anchor:SessionSerializer:InvalidImageSource", ...
                    "Image source session state must include Type, Name, and Data.");
            end

            state.Type = string(state.Type);
            state.Name = string(state.Name);
        end

        function state = normalizeHomographyState(state)
            requiredFields = ["AToB", "BToA", "TransformType"];
            missingFields = setdiff(requiredFields, string(fieldnames(state)));
            if ~isempty(missingFields)
                error("anchor:SessionSerializer:InvalidHomography", ...
                    "Homography state is missing required fields: %s.", ...
                    strjoin(missingFields, ", "));
            end

            state.AToB = double(state.AToB);
            state.BToA = double(state.BToA);
            state.TransformType = string(state.TransformType);
        end

        function state = normalizeViewportState(state)
            if ~isfield(state, "XLim") || ~isfield(state, "YLim")
                error("anchor:SessionSerializer:InvalidViewport", ...
                    "Viewport state must include XLim and YLim.");
            end

            state.XLim = double(state.XLim);
            state.YLim = double(state.YLim);
        end
    end
end
