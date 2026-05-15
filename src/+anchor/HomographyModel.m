classdef HomographyModel < handle
    %HomographyModel Registration state between image A and image B.

    properties (SetAccess = private)
        AToB (3, 3) double = eye(3)
        BToA (3, 3) double = eye(3)
        TransformType (1, 1) string = "identity"
    end

    methods
        function update(model, tiePoints)
            if ~isempty(tiePoints) && any(string(tiePoints.Properties.VariableNames) == "Enabled")
                tiePoints = tiePoints(tiePoints.Enabled, :);
            end

            if isempty(tiePoints) || height(tiePoints) == 0
                model.setTransform(eye(3), "identity");
                return
            end

            pointsA = [tiePoints.A_X, tiePoints.A_Y];
            pointsB = [tiePoints.B_X, tiePoints.B_Y];
            count = size(pointsA, 1);

            if count <= 2
                shift = mean(pointsB - pointsA, 1);
                h = [1 0 shift(1); 0 1 shift(2); 0 0 1];
                model.setTransform(h, "shift");
                return
            end

            if count == 3
                h = anchor.HomographyModel.estimateAffine(pointsA, pointsB);
                model.setTransform(h, "affine");
                return
            end

            try
                h = anchor.HomographyModel.estimateProjective(pointsA, pointsB);
                model.setTransform(h, "projective");
            catch
                shift = mean(pointsB - pointsA, 1);
                h = [1 0 shift(1); 0 1 shift(2); 0 0 1];
                model.setTransform(h, "shift-fallback");
            end
        end

        function points = mapPoints(model, points, sourceRole, targetRole)
            sourceRole = string(sourceRole);
            targetRole = string(targetRole);

            if sourceRole == targetRole
                return
            elseif sourceRole == "A" && targetRole == "B"
                h = model.AToB;
            elseif sourceRole == "B" && targetRole == "A"
                h = model.BToA;
            else
                error("anchor:HomographyModel:InvalidImageRole", ...
                    "Image roles must be ""A"" or ""B"".");
            end

            points = anchor.HomographyModel.applyTransform(h, points);
        end

        function targetState = mapViewport(model, sourceState, sourceRole, targetRole)
            corners = sourceState.getCorners();
            mappedCorners = model.mapPoints(corners, sourceRole, targetRole);

            targetState = anchor.ViewportState( ...
                [min(mappedCorners(:, 1)), max(mappedCorners(:, 1))], ...
                [min(mappedCorners(:, 2)), max(mappedCorners(:, 2))]);
        end

        function state = toSessionStruct(model)
            state = struct( ...
                "AToB", model.AToB, ...
                "BToA", model.BToA, ...
                "TransformType", model.TransformType);
        end

        function restoreFromSessionStruct(model, state)
            model.AToB = state.AToB ./ state.AToB(3, 3);
            model.BToA = state.BToA ./ state.BToA(3, 3);
            model.TransformType = string(state.TransformType);
        end
    end

    methods (Access = private)
        function setTransform(model, h, transformType)
            if any(~isfinite(h), "all") || abs(det(h)) < eps
                error("anchor:HomographyModel:InvalidTransform", ...
                    "Transform matrix must be finite and nonsingular.");
            end

            model.AToB = h ./ h(3, 3);
            model.BToA = inv(model.AToB);
            model.BToA = model.BToA ./ model.BToA(3, 3);
            model.TransformType = transformType;
        end
    end

    methods (Access = private, Static)
        function h = estimateAffine(pointsA, pointsB)
            design = [pointsA, ones(size(pointsA, 1), 1)];
            coefficients = design \ pointsB;

            h = [ ...
                coefficients(1, 1), coefficients(2, 1), coefficients(3, 1); ...
                coefficients(1, 2), coefficients(2, 2), coefficients(3, 2); ...
                0, 0, 1];
        end

        function h = estimateProjective(pointsA, pointsB)
            if size(pointsA, 1) < 4
                error("anchor:HomographyModel:InsufficientPoints", ...
                    "Projective homography requires at least four point pairs.");
            end

            rows = zeros(2 * size(pointsA, 1), 9);
            for index = 1:size(pointsA, 1)
                x = pointsA(index, 1);
                y = pointsA(index, 2);
                xp = pointsB(index, 1);
                yp = pointsB(index, 2);

                rows(2 * index - 1, :) = [-x -y -1 0 0 0 xp * x xp * y xp];
                rows(2 * index, :) = [0 0 0 -x -y -1 yp * x yp * y yp];
            end

            [~, ~, v] = svd(rows, 0);
            h = reshape(v(:, end), 3, 3)';

            if abs(h(3, 3)) < eps
                error("anchor:HomographyModel:DegenerateTransform", ...
                    "Estimated projective transform is degenerate.");
            end
        end

        function mapped = applyTransform(h, points)
            homogeneous = [points, ones(size(points, 1), 1)] * h';
            mapped = homogeneous(:, 1:2) ./ homogeneous(:, 3);
        end
    end
end
