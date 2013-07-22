{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE RecordWildCards #-}
module Bot.Component.Impl.NickCluster (
    ClusterNickHandle
,   newClusterNickHandle
,   clusterNickService
,   aliasesForNick
)   where

import              Bot.Component
import              Bot.Component.Combinator
import              Bot.Component.Command
import              Bot.Component.Stateful
import              Bot.IO

import              Control.Concurrent
import              Control.Exception
import              Control.Monad.State
import              Data.Clustering.Hierarchical
import              Data.Char
import              Data.List
import              Data.List.LCS
import qualified    Data.Set as S
import              Prelude hiding (catch)

-- | The internal state of the nick clustering service. The datatype is opaque
-- and should only be accessed through the exposed API.
data ClusterNickInfo = ClusterNickInfo {
    seenNicks   :: S.Set String -- ^ All of the nick's we are aware of
,   clusters    :: S.Set (S.Set String) -- ^ A list of all clusters
}

-- | Opaque type for the ClusterNickInfo that is exposed externally.
type ClusterNickHandle = MVar ClusterNickInfo

-- | Creates a new ClusterNickHandle for use with the clusterNickService
-- component. A reference to this required in order to make API calls.
newClusterNickHandle :: IO ClusterNickHandle
newClusterNickHandle = 
    liftIO $ newMVar ClusterNickInfo {seenNicks = S.empty, clusters = S.empty}

-- | The `BotComponent` portion of the nick clustering service. This service
-- must be included in the Bot otherwise all API calls will hang.
clusterNickService :: ClusterNickHandle -> Double -> Bot BotComponent
clusterNickService handle threshold =   liftIO (forkIO startClustering)
                                    >>  persistent nickFile action initial
    where
        nickFile = "nick-cluster.txt"
        delay = 1000000 -- 5 seconds

        -- Create the very first ClusterNickState
        initial = return S.empty

        -- The action that is passed to persistent
        action  =   nickWatcher 
                +++ commandT "!alias" aliasCommand

        -- Add every nick to the cache and to the handle's set of nicks
        nickWatcher _ = do
            BotState{..}                <-  lift get
            info@ClusterNickInfo{..}    <-  liftIO $ takeMVar handle
            seenNicks                   <-  liftM (addNick currentNick) get
            liftIO $ putMVar handle info { seenNicks }
            put seenNicks
            where
                addNick currentNick = S.filter (/= "") . S.insert currentNick


        -- Queries the alias clusters, if there is no arguments, it will list
        -- every cluster. Otherwise, it will list aliases for each name given.
        aliasCommand []     = do
            ClusterNickInfo{..} <-  liftIO $ readMVar handle
            mapM_ replyClusters $ S.elems clusters

        aliasCommand nicks  = do
            ClusterNickInfo{..} <-  liftIO $ readMVar handle
            let nickSet         =   S.fromList nicks
            let matches         =   S.filter (matchedFilter nickSet) clusters
            let unmatched       =   S.filter (unmatchedFilter clusters) nickSet
            mapM_ replyClusters $ S.elems matches
            mapM_ (lift . ircReply) $ S.elems unmatched
            where
                matchedFilter nickSet = not . S.null . S.intersection nickSet
                unmatchedFilter clusters = 
                    (`S.notMember` (S.unions $ S.elems clusters))

        -- Pretty prints a Set String of nicks to irc
        replyClusters = lift . ircReply . intercalate ", " . S.elems

        -- Create a time to update the ClusterNickInfo and kick off the
        -- clustering call the first time when the component is created
        startClustering = do
            clusterTimer `catch` handler 
            threadDelay delay
            startClustering
            where
                handler :: SomeException -> IO ()
                handler = void . return
                --handler = putStrLn . ("ERROR: NickCluster Error: "++) . show

        -- Computes a clustering of all the nicks currently present in the
        -- in the handle. It reads the nicks in a non-blocking manner so that
        -- updates may occur during clustering. Once the clusters have been
        -- computed it updates the handle with the current clustering of nicks.
        clusterTimer = do
            ClusterNickInfo{..} <-  readMVar handle
            let nickList        =   S.elems seenNicks
            let !clusters       =   S.fromList 
                                $   map (S.fromList . elements)
                                $   dendrogram SingleLinkage nickList distance
                                    `cutAt` threshold
            modifyMVar_ handle (\info -> return info {clusters})
        
        -- The distance function used for clustering. The distance between two
        -- nicks a and b is defined to be 1 - lcs(a,b)/(min(|a|,|b|). Or in
        -- other words 1 minus the ratio of the shorter nick appearing in the
        -- longer. 
        distance a b = 1 - (overlap / min lengthA lengthB)
            where
                a'      = map toLower a
                b'      = map toLower b
                overlap = fromIntegral $ length $ lcs a' b'
                lengthA = fromIntegral $ length a'
                lengthB = fromIntegral $ length b'
 
-- | Returns a list of nicks that have been determined to be aliases for the
-- supplied nick.
aliasesForNick :: ClusterNickHandle -> String -> Bot [String]
aliasesForNick handle nick = do
    ClusterNickInfo{..} <-  liftIO $ readMVar handle
    return  $ head . (++[[nick]])
            $ map S.elems
            $ S.elems
            $ S.filter (S.member nick) clusters
