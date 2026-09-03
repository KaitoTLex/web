module Xiangqi exposing (cssStyles, view)

import Html exposing (Html, div, h1, p, span, text)
import Html.Attributes exposing (attribute, class, style)
import VirtualDom


type alias Piece =
    { label : String
    , side : String
    , file : Int
    , rank : Int
    }


pieces : List Piece
pieces =
    [ Piece "車" "black" 0 0, Piece "馬" "black" 1 0, Piece "象" "black" 2 0, Piece "士" "black" 3 0, Piece "將" "black" 4 0, Piece "士" "black" 5 0, Piece "象" "black" 6 0, Piece "馬" "black" 7 0, Piece "車" "black" 8 0
    , Piece "砲" "black" 1 2, Piece "砲" "black" 7 2
    , Piece "卒" "black" 0 3, Piece "卒" "black" 2 3, Piece "卒" "black" 4 3, Piece "卒" "black" 6 3, Piece "卒" "black" 8 3
    , Piece "兵" "red" 0 6, Piece "兵" "red" 2 6, Piece "兵" "red" 4 6, Piece "兵" "red" 6 6, Piece "兵" "red" 8 6
    , Piece "炮" "red" 1 7, Piece "炮" "red" 7 7
    , Piece "俥" "red" 0 9, Piece "傌" "red" 1 9, Piece "相" "red" 2 9, Piece "仕" "red" 3 9, Piece "帥" "red" 4 9, Piece "仕" "red" 5 9, Piece "相" "red" 6 9, Piece "傌" "red" 7 9, Piece "俥" "red" 8 9
    ]


viewPiece : Piece -> Html msg
viewPiece piece =
    span
        [ class ("xiangqi-piece " ++ piece.side)
        , style "left" (String.fromFloat (toFloat piece.file / 8 * 100) ++ "%")
        , style "top" (String.fromFloat (toFloat piece.rank / 9 * 100) ++ "%")
        ]
        [ text piece.label ]


view : Html msg
view =
    div [ class "xiangqi-content" ]
        [ h1 [] [ text "象棋" ]
        , p [ class "xiangqi-intro" ] [ text "A small Chinese chess implementation is taking shape here." ]
        , div [ class "xiangqi-board-wrap" ]
            [ div
                [ class "xiangqi-board"
                , attribute "role" "img"
                , attribute "aria-label" "Chinese chess board in the starting position"
                ]
                ([ div [ class "xiangqi-river" ] [ span [] [ text "楚河" ], span [] [ text "漢界" ] ] ] ++ List.map viewPiece pieces)
            , div [ class "xiangqi-development-banner" ]
                [ span [ class "development-marker" ] [ text "// status" ]
                , text "currently being developed"
                ]
            ]
        ]


css : String
css =
    """
    .xiangqi-content {
      max-width: 760px;
    }

    .xiangqi-intro {
      color: var(--muted-color) !important;
      margin-bottom: 2rem !important;
    }

    .xiangqi-board-wrap {
      position: relative;
      width: min(100%, 600px);
      padding: 5.5%;
      border: 1px solid var(--border-color);
      border-radius: 6px;
      background: #cda66a;
      box-shadow: 0 12px 32px rgba(0, 0, 0, 0.2);
    }

    .xiangqi-board {
      position: relative;
      aspect-ratio: 8 / 9;
      background-color: #d9b777;
      background-image:
        repeating-linear-gradient(to right, transparent 0, transparent calc(12.5% - 0.5px), #5b4128 calc(12.5% - 0.5px), #5b4128 calc(12.5% + 0.5px)),
        repeating-linear-gradient(to bottom, transparent 0, transparent calc(11.111% - 0.5px), #5b4128 calc(11.111% - 0.5px), #5b4128 calc(11.111% + 0.5px));
      border: 1px solid #5b4128;
    }

    .xiangqi-river {
      position: absolute;
      z-index: 1;
      left: 0;
      right: 0;
      top: 44.45%;
      height: 11.111%;
      display: flex;
      align-items: center;
      justify-content: space-around;
      background: #d9b777;
      border-top: 1px solid #5b4128;
      border-bottom: 1px solid #5b4128;
      color: #5b4128;
      font-family: serif;
      font-size: clamp(0.9rem, 3vw, 1.65rem);
      letter-spacing: 0.35em;
    }

    .xiangqi-piece {
      position: absolute;
      z-index: 2;
      width: clamp(27px, 8.5%, 48px);
      aspect-ratio: 1;
      transform: translate(-50%, -50%);
      display: grid;
      place-items: center;
      border: 2px solid currentColor;
      border-radius: 50%;
      background: #ead29c;
      font-family: serif;
      font-size: clamp(0.82rem, 2.6vw, 1.45rem);
      font-weight: 700;
      box-shadow: 0 2px 4px rgba(55, 35, 18, 0.42), inset 0 0 0 2px #ead29c, inset 0 0 0 3px currentColor;
    }

    .xiangqi-piece.black { color: #26211d; }
    .xiangqi-piece.red { color: #a8322d; }

    .xiangqi-development-banner {
      position: absolute;
      z-index: 4;
      left: -1px;
      right: -1px;
      top: 50%;
      transform: translateY(-50%) rotate(-1.5deg);
      display: flex;
      justify-content: center;
      align-items: baseline;
      gap: 0.8rem;
      padding: 1rem;
      background: rgba(37, 35, 52, 0.96);
      border: 1px solid var(--accent-color);
      color: #e8e6f0;
      font-size: clamp(0.82rem, 2.4vw, 1.05rem);
      text-transform: uppercase;
      letter-spacing: 0.08em;
      box-shadow: 0 8px 22px rgba(0, 0, 0, 0.35);
    }

    .development-marker {
      color: var(--accent-color);
      font-size: 0.68em;
    }

    @media (max-width: 520px) {
      .xiangqi-board-wrap { padding: 7%; }
      .xiangqi-development-banner { flex-direction: column; align-items: center; gap: 0.15rem; }
    }
    """


cssStyles : Html msg
cssStyles =
    VirtualDom.node "style" [] [ text css ]
