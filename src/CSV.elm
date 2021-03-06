module CSV
    exposing
        ( getAvatarList
        , avatarListToString
        , avatarListExample
        , networkFromString
        , simpleEdgeListFromString
        , singleLineFromCSV
        , csvFromSingleLine
        , csvFromEdgeList
        , example
        )

import Parser exposing (..)
import Parser.Extras exposing (many)
import Tools exposing (unique)
import Network
    exposing
        ( Network(..)
        , Node
        , SimpleEdge(..)
        , Edge(..)
        , createNode
        , sourceNameOfSimpleEdge
        , sinkNameOfSimpleEdge
        , stringOfSimpleEdge
        )
import NetworkParser
    exposing
        ( identifier
        , nodesFromString
        , simpleEdgeListFromString
        , edgeListFromString
        , stringOfSimpleEdgeList
        , NodeUrl(..)
        )


singleLineFromCSV : String -> String
singleLineFromCSV csv =
    csv
        |> simpleEdgeListFromString
        |> stringOfSimpleEdgeList


csvFromSingleLine : String -> String
csvFromSingleLine str =
    str
        |> simpleEdgeListFromString
        |> csvFromEdgeList


csvFromEdgeList : List SimpleEdge -> String
csvFromEdgeList sel =
    sel
        |> List.map csvOfSimpleEdge
        |> String.join ("")


csvOfSimpleEdge : SimpleEdge -> String
csvOfSimpleEdge (SimpleEdge sourceNode targetNode flow) =
    sourceNode ++ ", " ++ targetNode ++ ", " ++ String.fromFloat flow ++ "\n"


networkFromString : String -> Network
networkFromString str =
    Network (nodesFromString str) (edgeListFromCSV str)


nodeNamesFromString : String -> List String
nodeNamesFromString str =
    let
        simpleEdgeList =
            simpleEdgeListFromString str

        sourceNodeNames =
            simpleEdgeList |> List.map sourceNameOfSimpleEdge

        sinkNodeNames =
            simpleEdgeList |> List.map sinkNameOfSimpleEdge
    in
        sourceNodeNames ++ sinkNodeNames |> unique |> List.sort


nodesFromString : String -> List Node
nodesFromString str =
    nodeNamesFromString str
        |> List.map (\str_ -> createNode str_ "")


normalize : String -> String
normalize str =
    str
        |> String.trim
        |> \x -> x ++ "\n"


edgeListFromCSV : String -> List Edge
edgeListFromCSV str =
    simpleEdgeListFromString (str |> normalize)
        |> Network.edgeListFromSimpleEdgeList


simpleEdgeListFromString : String -> List SimpleEdge
simpleEdgeListFromString str =
    case run simpleEdgeListParser (String.trim str) of
        Err _ ->
            []

        Ok edgeList ->
            edgeList


simpleEdgeListParser : Parser (List SimpleEdge)
simpleEdgeListParser =
    many simpleEdgeParser


simpleEdgeParser : Parser SimpleEdge
simpleEdgeParser =
    succeed SimpleEdge
        |= identifier
        |. symbol ","
        |. spaces
        |= identifier
        |. symbol ","
        |. spaces
        |= float
        |. spaces


avatarParser : Parser NodeUrl
avatarParser =
    succeed NodeUrl
        |= identifier
        |. symbol ","
        |. spaces
        |= NetworkParser.url
        |. symbol "\n"


avatarListParser : Parser (List NodeUrl)
avatarListParser =
    many avatarParser


getAvatarList : String -> List NodeUrl
getAvatarList csv =
    case Parser.run avatarListParser (normalize csv) of
        Ok result ->
            result

        Err _ ->
            []


avatarListToString : List NodeUrl -> String
avatarListToString avatarList =
    avatarList
        |> List.map csvOfAvatar
        |> String.join ""


csvOfAvatar : NodeUrl -> String
csvOfAvatar (NodeUrl name url) =
    name ++ ", " ++ url ++ "\n"


example =
    "  \nA,B,23\nA,C,10\nB,D,40\nC,D,5  \n"


avatarListExample =
    "Jim, http://foo.edu/hoho.jpg\nLucca, ipfs://bar.edu/haha.jpg\n"
