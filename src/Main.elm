module Main exposing (main)

import Browser
import Browser.Navigation exposing (Key)
import Html exposing (Html, a, button, div, footer, h1, h2, img, p, span, text)
import Html.Attributes exposing (alt, class, href, src, style)
import Html.Events exposing (onClick)
import Url
import Url.Parser as Parser exposing (Parser, map, oneOf, s, top)
import VirtualDom
import Projects exposing (viewProjects, cssStyles)


main : Program () Model Msg
main =
    Browser.application
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        , onUrlChange = UrlChanged
        , onUrlRequest = LinkClicked
        }


-- MODEL


type ColorMode
    = LightMode
    | DarkMode


type Page
    = Home
    | ProjectsPage
    | NotFound


type alias Model =
    { key : Key
    , url : Url.Url
    , colorMode : ColorMode
    , commitHash : String
    , mobileMenuOpen : Bool
    }


init : () -> Url.Url -> Key -> ( Model, Cmd Msg )
init _ url key =
    ( { key = key
      , url = url
      , colorMode = DarkMode
      , commitHash = "GITHUB_ACTIONS_COMMIT_HASH_PLACEHOLDER"
      , mobileMenuOpen = False
      }
    , Cmd.none
    )


-- UPDATE


type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url
    | ToggleColorMode
    | ToggleMobileMenu


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LinkClicked urlRequest ->
            case urlRequest of
                Browser.Internal url ->
                    ( model, Browser.Navigation.pushUrl model.key (Url.toString url) )

                Browser.External href ->
                    ( model, Browser.Navigation.load href )

        UrlChanged url ->
            ( { model | url = url }, Cmd.none )

        ToggleColorMode ->
            let
                newMode =
                    if model.colorMode == DarkMode then
                        LightMode
                    else
                        DarkMode
            in
            ( { model | colorMode = newMode }, Cmd.none )

        ToggleMobileMenu ->
            ( { model | mobileMenuOpen = not model.mobileMenuOpen }, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none


-- VIEW


view : Model -> Browser.Document Msg
view model =
    { title = "KaitoTLex.Systems"
    , body =
        [ css <| buildCss model
        , Projects.cssStyles
        , div [ class "container" ]
            [ div [ class "branding" ]
                [ div [ class "logo" ]
                    [ VirtualDom.node "svg"
                        [ Html.Attributes.attribute "viewBox" "0 0 24 24"
                        , Html.Attributes.attribute "width" "32"
                        , Html.Attributes.attribute "height" "32"
                        , style "margin-right" "1rem"
                        ]
                        [ VirtualDom.node "path"
                            [ Html.Attributes.attribute "d" "M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5" ]
                            []
                        ]
                    ]
                , h1 [] [ text "Ren Lin" ]
                , p [] [ text "kaitotlex.systems" ]
                , button [ class "mobile-menu-toggle", onClick ToggleMobileMenu ]
                    [ text (if model.mobileMenuOpen then "✕" else "☰")
                    , span [ class "sr-only" ] [ text "Menu" ]
                    ]
                ]
            , div [ class "content-wrapper" ]
                [ if not model.mobileMenuOpen then
                    div [ class "sidebar" ]
                        [ h2 [] [ text "dir" ]
                        , div [ class "nav-links" ]
                            [ a [ href "/", onClick (LinkClicked (Browser.Internal (Url.fromString "/" |> Maybe.withDefault model.url))) ] [ text "home" ]
                            , a [ href "/about", onClick (LinkClicked (Browser.Internal (Url.fromString "/about" |> Maybe.withDefault model.url))) ] [ text "about" ]
                            , a [ href "/projects", onClick (LinkClicked (Browser.Internal (Url.fromString "/projects" |> Maybe.withDefault model.url))) ] [ text "projects" ]
                            , a [ href "https://eexiv.functor.systems/author/wlin" ] [ text "personal research" ]
                            , a [ href "https://yap.kaitotlex.systems" ] [ text "log" ]
                            , a [ href "/cont/cv.pdf" ] [ text "download CV" ]
                            ]
                        , h2 [] [ text "orgs" ]
                        , div [ class "org-links" ]
                            [ a [ href "https://functor.systems/" ] [ text "functor.systems" ]
                            , a [ href "https://inlabs.kaitotlex.systems" ] [ text "InLabs" ]
                            ]
                        , div [ class "mode-toggle-container" ]
                            [ button [ class "mode-toggle", onClick ToggleColorMode ]
                                [ text (if model.colorMode == DarkMode then "Light Mode" else "Dark Mode")
                                , span [ class "toggle-icon" ]
                                    [ if model.colorMode == DarkMode then
                                        VirtualDom.node "svg"
                                            [ Html.Attributes.attribute "viewBox" "0 0 24 24"
                                            , Html.Attributes.attribute "width" "16"
                                            , Html.Attributes.attribute "height" "16"
                                            ]
                                            [ VirtualDom.node "path"
                                                [ Html.Attributes.attribute "d" "M12 10c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2zm0-8c-3.3 0-6 2.7-6 6 0 1.8 0.8 3.4 2.1 4.5l-.2.3-1.9 2.8h10l-1.9-2.8-.2-.3c1.3-1.1 2.1-2.6 2.1-4.5 0-3.3-2.7-6-6-6zm-8 14v2h16v-2h-16z" ]
                                                []
                                            ]

                                      else
                                        VirtualDom.node "svg"
                                            [ Html.Attributes.attribute "viewBox" "0 0 24 24"
                                            , Html.Attributes.attribute "width" "16"
                                            , Html.Attributes.attribute "height" "16"
                                            ]
                                            [ VirtualDom.node "path"
                                                [ Html.Attributes.attribute "d" "M20 8.69V4h-4.69L12 .69 8.69 4H4v4.69L.69 12 4 15.31V20h4.69L12 23.31 15.31 20H20v-4.69L23.31 12 20 8.69zM12 18c-3.31 0-6-2.69-6-6s2.69-6 6-6 6 2.69 6 6-2.69 6-6 6zm0-10c-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4-1.79-4-4-4z" ]
                                                []
                                            ]
                                    ]
                                ]
                            ]
                        ]

                  else
                    div [ class "mobile-menu-overlay", onClick ToggleMobileMenu ]
                        [ div [ class "mobile-menu", onClick (\_ -> NoOp) ]
                            [ div [ class "mobile-menu-header" ]
                                [ h2 [] [ text "Menu" ]
                                , button [ class "close-mobile-menu", onClick ToggleMobileMenu ] [ text "Close" ]
                                ]
                            , div [ class "mobile-nav-links" ]
                                [ a [ href "/", onClick (LinkClicked (Browser.Internal (Url.fromString "/" |> Maybe.withDefault model.url))), class "mobile-nav-item" ] [ text "home" ]
                                , a [ href "/about", onClick (LinkClicked (Browser.Internal (Url.fromString "/about" |> Maybe.withDefault model.url))), class "mobile-nav-item" ] [ text "about" ]
                                , a [ href "/projects", onClick (LinkClicked (Browser.Internal (Url.fromString "/projects" |> Maybe.withDefault model.url))), class "mobile-nav-item" ] [ text "projects" ]
                                , a [ href "https://eexiv.functor.systems/author/wlin", class "mobile-nav-item" ] [ text "personal research" ]
                                , a [ href "https://yap.kaitotlex.systems", class "mobile-nav-item" ] [ text "log" ]
                                , a [ href "/cont/cv.pdf", class "mobile-nav-item" ] [ text "download CV" ]
                                ]
                            , h2 [] [ text "Organizations" ]
                            , div [ class "mobile-org-links" ]
                                [ a [ href "https://functor.systems/", class "mobile-nav-item" ] [ text "functor.systems" ]
                                , a [ href "https://inlabs.kaitotlex.systems", class "mobile-nav-item" ] [ text "InLabs" ]
                                ]
                            ]
                        ]
                , div [ class "main-content" ]
                    [ case parseUrl model.url of
                        Home ->
                            div []
                                [ h1 [] [ text "oh Hi!" ]
                                , p [] [ text "I am Ren or Warren, I am a High School student studying Nuclear Theory and Electrical Engineering" ]
                                , img [ src "/cont/bike.jpg", alt "Bike", class "responsive-image" ] []
                                , p [] [ text "I am interested in semi-conductor manufacturing, SOCs, and low power hardware. I work on projects that involves low power hardware -- anything RISC. I can't code. I like FOSS and FOSH, including RISC-V." ]
                                , p [] [ text "I like cycling and sim-racing. I watch MLB, NPB, F1, WEC, and WRC as a sport. I play the piano, bass and saxophone (Tenor && Alto). I do RE and hardware hacking in my freetime" ]
                                , p [] [ text "I play too much rythm games" ]
                                , p [] [ text "If you would like to learn more about me, send a Matrix message or read my logs." ]
                                , h2 [] [ text "contact" ]
                                , div [ class "contact-links" ]
                                    [ a [ href "https://web.kaitotlex.systems", class "contact-item" ] [ text "kaitotlex.systems" ]
                                    , a [ href "mailto:rlin@kaitotlex.systems", class "contact-item" ] [ text "send a email (please sign with pgp)" ]
                                    , a [ href "https://bsky.app/profile/kaitotlex.systems", class "contact-item" ] [ text "bluesky" ]
                                    , a [ href "https://x.com/Kaito_Malfoy", class "contact-item" ] [ text "X (formerly twitter)" ]
                                    , a [ href "https://github.com/kaitotlex", class "contact-item" ] [ text "github" ]
                                    , a [ href "https://osu.ppy.sh/users/26069038", class "contact-item" ] [ text "osu" ]
                                    , a [ href "https://arxiv.org/abs/2204.04549", class "contact-item" ] [ text "send ripples through the maxwell matter wave" ]
                                    ]
                                ]

                        ProjectsPage ->
                            Projects.viewProjects

                        NotFound ->
                            div [ class "main-content" ]
                                [ h1 [] [ text "404 - Page Not Found" ]
                                , p [] [ text "The page you're looking for doesn't exist." ]
                                ]
                    ]
                ]
            , footer [ class "copyright-footer" ]
                [ text "2025 © KaitoTLex on Elm, all rights reserved"
                , span [ class "commit-info" ]
                    [ text " source: "
                    , a
                        [ href ("https://github.com/kaitotlex/web/commit/" ++ model.commitHash)
                        , class "commit-link"
                        ]
                        [ text model.commitHash ]
                    ]
                ]
            ]
        ]
    }


parseUrl : Url.Url -> Page
parseUrl url =
    case Parser.parse routeParser url of
        Just page ->
            page

        Nothing ->
            NotFound


routeParser : Parser (Page -> a) a
routeParser =
    oneOf
        [ Parser.map Home top
        , Parser.map Home (s "about")
        , Parser.map ProjectsPage (s "projects")
        ]


buildCss : Model -> String
buildCss model =
    let
        -- Direct color values based on current mode
        bg =
            if model.colorMode == DarkMode then
                "#3d3653"
            else
                "#c5c2d6"

        text =
            if model.colorMode == DarkMode then
                "#c5c2d6"
            else
                "#3d3653"

        brandingBg =
            if model.colorMode == DarkMode then
                "#4e4864"
            else
                "#a39fb6"

        sidebarBorder =
            if model.colorMode == DarkMode then
                "#5f5974"
            else
                "#817c95"

        buttonBg =
            if model.colorMode == DarkMode then
                "#5f5974"
            else
                "#817c95"

        buttonText =
            if model.colorMode == DarkMode then
                "#c5c2d6"
            else
                "#3d3653"

        linkColor =
            if model.colorMode == DarkMode then
                "#a39fb6"
            else
                "#5f5974"

        linkHover =
            "#817c95"
    in
    """
    @import url('https://fonts.googleapis.com/css2?family=Fira+Code:wght@400;500;600&display=swap');
    
    :root {
      --english-violet: #3d3653;
      --english-violet-2: #423b58;
      --english-violet-3: #463f5c;
      --english-violet-4: #4e4864;
      --ultra-violet: #5f5974;
      --cool-gray: #817c95;
      --rose-quartz: #a39fb6;
      --french-gray: #c5c2d6;
    }
    
    body {
      font-family: 'Fira Code', monospace;
      background-color: """ ++ bg ++ """;
      color: """ ++ text ++ """;
      line-height: 1.6;
      margin: 0;
      padding: 0;
      min-height: 100vh;
      transition: background-color 0.3s ease, color 0.3s ease;
    }
    
    a {
      color: """ ++ linkColor ++ """;
      text-decoration: none;
      transition: all 0.2s ease;
    }
    
    a:hover {
      color: """ ++ linkHover ++ """;
    }
    
    .container {
      max-width: 1200px;
      margin: 0 auto;
      padding: 2rem;
      display: flex;
      flex-direction: column;
      min-height: 100vh;
    }
    
    .branding {
      background-color: """ ++ brandingBg ++ """;
      padding: 1rem;
      text-align: center;
      position: sticky;
      top: 0;
      z-index: 100;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 0.5rem;
    }
    
    .logo {
      display: flex;
      align-items: center;
    }
    
    .content-wrapper {
      display: grid;
      grid-template-columns: 1fr 3fr;
      gap: 2rem;
      margin-top: 2rem;
      flex-grow: 1;
    }
    
    .sidebar {
      border-right: 1px solid """ ++ sidebarBorder ++ """;
      padding-right: 2rem;
    }
    
    .main-content {
      padding: 1rem 0;
    }
    
    h1, h2, h3 {
      color: """ ++ text ++ """;
      margin-top: 1.5rem;
    }
    
    .nav-links, .org-links {
      display: flex;
      flex-direction: column;
    }
    
    .nav-links a, .org-links a {
      display: block;
      padding: 0.75rem 0;
    }
    
    .contact-links {
      display: flex;
      flex-direction: column;
      gap: 0.75rem;
      margin-top: 1rem;
    }
    
    .contact-item {
      display: block;
    }
    
    /* Responsive image styling */
    .responsive-image {
      max-width: 100%;
      height: auto;
      display: block;
      margin: 1.5rem auto;
      border-radius: 8px;
      box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
    }
    
    @media (max-width: 768px) {
      .responsive-image {
        margin: 1rem auto;
        max-width: 95%;
      }
    }
    
    .mobile-menu-toggle {
      display: none;
      background: none;
      border: none;
      color: currentColor;
      font-size: 1.5rem;
      cursor: pointer;
      margin-left: auto;
      position: relative;
      z-index: 1001;
    }
    
    .mobile-menu-overlay {
      position: fixed;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      background-color: rgba(0, 0, 0, 0.5);
      z-index: 999;
      display: flex;
      align-items: flex-start;
      justify-content: flex-end;
    }
    
    .mobile-menu {
      background-color: """ ++ bg ++ """;
      width: 80%;
      max-width: 400px;
      height: 100%;
      padding: 1.5rem;
      overflow-y: auto;
      box-shadow: -2px 0 10px rgba(0, 0, 0, 0.1);
    }
    
    .mobile-menu-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 1.5rem;
    }
    
    .mobile-nav-links, .mobile-org-links {
      display: flex;
      flex-direction: column;
      margin-top: 1rem;
    }
    
    .mobile-nav-item {
      padding: 1.25rem 0;
      border-bottom: 1px solid """ ++ sidebarBorder ++ """;
      font-size: 1.2rem;
      line-height: 1.4;
    }
    
    .close-mobile-menu {
      background: none;
      border: none;
      color: currentColor;
      font-size: 1.2rem;
      cursor: pointer;
      padding: 0.25rem 0.5rem;
    }
    
    .copyright-footer {
      text-align: center;
      padding: 1.5rem 0;
      font-size: 0.85rem;
      opacity: 0.7;
      border-top: 1px solid """ ++ sidebarBorder ++ """;
      margin-top: auto;
    }
    
    .copyright-footer a {
      color: """ ++ linkColor ++ """;
      text-decoration: underline;
    }
    
    .copyright-footer a:hover {
      color: """ ++ linkHover ++ """;
      text-decoration: underline;
    }
    
    .mode-toggle {
      background-color: """ ++ buttonBg ++ """;
      color: """ ++ buttonText ++ """;
      border: none;
      padding: 0.75rem 1.5rem;
      border-radius: 4px;
      cursor: pointer;
      z-index: 1000;
      display: inline-flex;
      align-items: center;
      gap: 0.5rem;
      transition: all 0.3s ease;
      box-shadow: 0 2px 5px rgba(0,0,0,0.2);
      margin-top: 1rem;
    }
    
    .mode-toggle:hover {
      background-color: """ ++ linkHover ++ """;
      transform: translateY(-2px);
    }
    
    @media (max-width: 768px) {
      :root {
        --font-size-base: 16px;
        --font-size-h1: 1.8rem;
        --font-size-h2: 1.4rem;
        --font-size-body: 1.1rem;
        --spacing-unit: 1rem;
      }
      
      .container {
        padding: 1rem;
      }
      
      .branding {
        padding: 0.75rem;
        flex-direction: column;
        align-items: flex-start;
      }
      
      .mobile-menu-toggle {
        display: block;
      }
      
      .content-wrapper {
        grid-template-columns: 1fr;
        margin-top: 1rem;
      }
      
      .sidebar {
        display: none;
      }
      
      .mobile-menu-overlay {
        display: flex;
      }
      
      .mobile-menu {
        width: 90%;
        padding: 1.5rem;
      }
      
      .mobile-nav-links, .mobile-org-links {
        gap: 1rem;
      }
      
      .mobile-nav-item {
        padding: 1.25rem 0;
        font-size: 1.2rem;
        line-height: 1.4;
      }
      
      .main-content {
        padding: 1rem 0.5rem;
      }
      
      h1 {
        font-size: var(--font-size-h1);
      }
      
      h2 {
        font-size: var(--font-size-h2);
        margin-top: 1.5rem;
      }
      
      p {
        font-size: var(--font-size-body);
        line-height: 1.6;
      }
      
      .nav-links a, .org-links a {
        padding: 1rem 0;
        font-size: 1.1rem;
      }
      
      .mode-toggle {
        padding: 0.75rem 1.25rem;
        font-size: 1rem;
        margin-top: 1.5rem;
      }
      
      .copyright-footer {
        padding: 1.25rem 0;
        font-size: 0.95rem;
      }
    }
    """


css : String -> Html msg
css cssContent =
    VirtualDom.node "style" [] [ text cssContent ]