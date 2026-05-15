classdef ViewportState
    %ViewportState Immutable image viewport description.

    properties
        XLim (1, 2) double
        YLim (1, 2) double
    end

    methods
        function state = ViewportState(xLim, yLim)
            arguments
                xLim (1, 2) double
                yLim (1, 2) double
            end

            state.XLim = sort(xLim);
            state.YLim = sort(yLim);
        end

        function center = getCenter(state)
            center = [mean(state.XLim), mean(state.YLim)];
        end

        function width = getWidth(state)
            width = diff(state.XLim);
        end

        function height = getHeight(state)
            height = diff(state.YLim);
        end

        function corners = getCorners(state)
            corners = [ ...
                state.XLim(1), state.YLim(1); ...
                state.XLim(2), state.YLim(1); ...
                state.XLim(2), state.YLim(2); ...
                state.XLim(1), state.YLim(2)];
        end

        function shiftedState = translate(state, shift)
            arguments
                state
                shift (1, 2) double
            end

            shiftedState = anchor.ViewportState( ...
                state.XLim + shift(1), state.YLim + shift(2));
        end
    end
end
