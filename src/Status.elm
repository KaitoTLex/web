module Status exposing (StatusSnapshot, StatusState(..), cssStyles, fetchApi, services, view)

import Dict exposing (Dict)
import Html exposing (Html, a, button, div, h1, p, span, text)
import Html.Attributes exposing (class, href, style, title)
import Html.Events exposing (onClick)
import Http
import Json.Decode as Decode exposing (Decoder)
import VirtualDom


-- TYPES


type StatusState
    = StatusIdle
    | StatusLoading
    | StatusLoaded (List StatusSnapshot)
    | StatusFailed String


type alias StatusSnapshot =
    { timestamp : String
    , statuses : Maybe (Dict String String)
    }


-- SERVICE INFO


type alias ServiceInfo =
    { name : String
    , description : String
    }


serviceInfoList : List ServiceInfo
serviceInfoList =
    [ { name = "code.functor.systems"
      , description = "Forgejo instance where most of the code from functor.systems live on, hosted on anton(Danville, CA)"
      }
    , { name = "matrix.functor.systems"
      , description = "Matrix federation homelab service hosted on a VPS"
      }
    , { name = "slop.kaitotlex.engineering"
      , description = "AgentSwarm™ openclaw instance, hosted on anton(Danville, CA)"
      }
    , { name = "yap.kaitotlex.systems"
      , description = "(planned) blog, hosted on github pages"
      }
    , { name = "missioncontrol.kaitotlex.systems"
      , description = "status of anton, hosted on anton(Danville, CA)"
      }
    , { name = "functor.mit.edu"
      , description = "mirror of functor.systems website, hosted on gallium(Cambridge, MA)"
      }
    ]


services : List String
services =
    List.map .name serviceInfoList


-- HTTP / DECODE


snapshotDecoder : Decoder StatusSnapshot
snapshotDecoder =
    Decode.map2 StatusSnapshot
        (Decode.field "timestamp" Decode.string)
        (Decode.field "statuses" (Decode.nullable (Decode.dict Decode.string)))


fetchApi : (Result Http.Error (List StatusSnapshot) -> msg) -> Cmd msg
fetchApi toMsg =
    Http.get
        { url = "/status.json"
        , expect =
            Http.expectJson toMsg
                (Decode.field "history" (Decode.list snapshotDecoder))
        }


-- VIEW HELPERS


{-| Extract "HH:MM" from an ISO-8601 timestamp like "2025-04-09T10:00:00.000Z"
-}
hourLabel : String -> String
hourLabel ts =
    ts
        |> String.dropLeft 11
        |> String.left 5


{-| Most recent non-null status for a service across the history list.
-}
currentStatusFor : List StatusSnapshot -> String -> Maybe String
currentStatusFor history name =
    history
        |> List.reverse
        |> List.filterMap .statuses
        |> List.head
        |> Maybe.andThen (Dict.get name)


segmentBg : Maybe String -> String
segmentBg status =
    case status of
        Just "online" ->
            "#6db56d"

        Just "degraded" ->
            "#d4a46b"

        Just "offline" ->
            "#d46b6b"

        _ ->
            "var(--border-color)"


viewSegment : List StatusSnapshot -> String -> Int -> Html msg
viewSegment history serviceName idx =
    let
        snapshot =
            history |> List.drop idx |> List.head

        serviceStatus =
            snapshot
                |> Maybe.andThen .statuses
                |> Maybe.andThen (Dict.get serviceName)

        ts =
            snapshot |> Maybe.map .timestamp |> Maybe.withDefault ""

        tooltipText =
            hourLabel ts ++ " — " ++ Maybe.withDefault "no data" serviceStatus
    in
    div
        [ class "ribbon-segment"
        , style "background-color" (segmentBg serviceStatus)
        , title tooltipText
        ]
        []


viewTicks : List StatusSnapshot -> Html msg
viewTicks history =
    let
        tickAt i =
            history
                |> List.drop i
                |> List.head
                |> Maybe.map (.timestamp >> hourLabel)
                |> Maybe.withDefault ""
    in
    if List.isEmpty history then
        div [ class "history-ticks" ] []

    else
        div [ class "history-ticks" ]
            [ span [ class "tick-label" ] [ text (tickAt 0) ]
            , span [ class "tick-label" ] [ text (tickAt 4) ]
            , span [ class "tick-label" ] [ text (tickAt 8) ]
            , span [ class "tick-label" ] [ text (tickAt 11) ]
            ]


viewServiceCard : Bool -> List StatusSnapshot -> ServiceInfo -> Html msg
viewServiceCard isLoading history info =
    let
        currentStatus =
            if isLoading then
                Nothing

            else
                currentStatusFor history info.name

        dotClass =
            if isLoading then
                "status-dot checking"

            else
                case currentStatus of
                    Just "online" ->
                        "status-dot online"

                    Just "degraded" ->
                        "status-dot degraded"

                    Just "offline" ->
                        "status-dot offline"

                    _ ->
                        "status-dot unknown"

        badgeText =
            if isLoading then
                "checking..."

            else
                Maybe.withDefault "unknown" currentStatus

        badgeClass =
            if isLoading then
                "status-badge"

            else
                case currentStatus of
                    Just "online" ->
                        "status-badge online"

                    Just "degraded" ->
                        "status-badge degraded"

                    Just "offline" ->
                        "status-badge offline"

                    _ ->
                        "status-badge"

        ribbonSegments =
            if List.isEmpty history then
                -- Loading placeholder: 12 grey pulsing segments
                List.repeat 12 (div [ class "ribbon-segment placeholder" ] [])

            else
                List.indexedMap (\i _ -> viewSegment history info.name i) history
    in
    div [ class "status-card" ]
        [ div [ class "card-header" ]
            [ div [ class "card-title-row" ]
                [ span [ class dotClass ] []
                , a [ href ("https://" ++ info.name), class "service-link" ] [ text info.name ]
                ]
            , span [ class badgeClass ] [ text badgeText ]
            ]
        , p [ class "service-description" ] [ text info.description ]
        , div [ class "history-ribbon" ] ribbonSegments
        , viewTicks history
        ]


view : StatusState -> msg -> Html msg
view state refreshMsg =
    let
        ( isLoading, history ) =
            case state of
                StatusLoading ->
                    ( True, [] )

                StatusLoaded h ->
                    ( False, h )

                _ ->
                    ( False, [] )
    in
    div [ class "status-container" ]
        [ div [ class "status-header-row" ]
            [ div []
                [ h1 [ class "status-header" ] [ text "statuses" ]
                , p [ class "status-subheader" ] [ text "functor.systems members keep making fun of indeterministic reliability from my services so i decided to put this on my personal website" ]
                ]
            , button [ class "status-refresh", onClick refreshMsg ] [ text "[ refresh ]" ]
            ]
        , div [ class "status-grid" ]
            (List.map (viewServiceCard isLoading history) serviceInfoList)
        ]


-- CSS


css : String
css =
    """
    .status-container {
      max-width: 760px;
    }

    .status-header-row {
      display: flex;
      justify-content: space-between;
      align-items: flex-start;
      margin-bottom: 2rem;
    }

    .status-header {
      font-size: 1.8rem;
      font-weight: 600;
      margin-top: 0;
      margin-bottom: 0.3rem;
    }

    .status-subheader {
      font-size: 0.88rem;
      color: var(--muted-color);
      margin: 0;
    }

    .status-grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 1rem;
    }

    .status-card:last-child:nth-child(odd) {
      grid-column: span 2;
    }

    .status-card {
      background-color: var(--surface-color);
      border: 1px solid var(--border-color);
      border-radius: 6px;
      padding: 1.25rem 1.5rem;
      transition: border-color 0.2s ease;
    }

    .status-card:hover {
      border-color: var(--accent-color);
    }

    .card-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 0.5rem;
      gap: 0.5rem;
    }

    .card-title-row {
      display: flex;
      align-items: center;
      gap: 0.6rem;
      min-width: 0;
      flex: 1;
      overflow: hidden;
    }

    .status-dot {
      width: 8px;
      height: 8px;
      border-radius: 50%;
      flex-shrink: 0;
    }

    .status-dot.online   { background-color: #6db56d; }
    .status-dot.offline  { background-color: #d46b6b; }
    .status-dot.degraded { background-color: #d4a46b; }

    .status-dot.checking {
      background-color: var(--muted-color);
      animation: status-pulse 1.5s ease-in-out infinite;
    }

    .status-dot.unknown {
      background-color: var(--muted-color);
      opacity: 0.45;
    }

    @keyframes status-pulse {
      0%, 100% { opacity: 1; }
      50%       { opacity: 0.2; }
    }

    .service-link {
      font-size: 0.83rem;
      color: var(--link-color);
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
      min-width: 0;
    }

    .service-link:hover {
      color: var(--link-hover-color);
    }

    .status-badge {
      font-size: 0.72rem;
      color: var(--muted-color);
      font-family: 'Fira Code', monospace;
      white-space: nowrap;
      flex-shrink: 0;
    }

    .status-badge.online   { color: #6db56d; }
    .status-badge.offline  { color: #d46b6b; }
    .status-badge.degraded { color: #d4a46b; }

    .service-description {
      font-size: 0.78rem;
      color: var(--muted-color);
      margin: 0 0 0.875rem;
      line-height: 1.55;
    }

    /* ── Ribbon / line chart ────────────────────────── */

    .history-ribbon {
      display: flex;
      gap: 2px;
      height: 8px;
      border-radius: 4px;
      overflow: hidden;
    }

    .ribbon-segment {
      flex: 1;
      cursor: default;
      transition: opacity 0.12s ease;
    }

    .ribbon-segment:hover {
      opacity: 0.65;
    }

    .ribbon-segment.placeholder {
      background-color: var(--border-color);
      animation: status-pulse 2s ease-in-out infinite;
    }

    /* ── Tick labels ────────────────────────────────── */

    .history-ticks {
      display: flex;
      justify-content: space-between;
      margin-top: 0.3rem;
    }

    .tick-label {
      font-size: 0.62rem;
      color: var(--muted-color);
      opacity: 0.55;
      font-family: 'Fira Code', monospace;
    }

    /* ── Refresh button ─────────────────────────────── */

    .status-refresh {
      background: none;
      border: 1px solid var(--border-color);
      color: var(--muted-color);
      font-family: 'Fira Code', monospace;
      font-size: 0.78rem;
      padding: 0.3rem 0.75rem;
      border-radius: 4px;
      cursor: pointer;
      transition: color 0.15s ease, border-color 0.15s ease;
      align-self: flex-start;
      margin-top: 0.25rem;
    }

    .status-refresh:hover {
      color: var(--text-color);
      border-color: var(--accent-color);
    }

    @media (max-width: 768px) {
      .status-header-row {
        flex-direction: column;
        gap: 1rem;
      }

      .status-grid {
        grid-template-columns: 1fr;
      }

      .status-card:last-child:nth-child(odd) {
        grid-column: span 1;
      }
    }
    """


cssStyles : Html msg
cssStyles =
    VirtualDom.node "style" [] [ text css ]
