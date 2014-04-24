module Bot.Component.Regex (
    regex
,   regexT
)   where

import Bot.Component
import Bot.IO

import Control.Monad.Trans
import Control.Monad.Trans.Identity
import Text.Regex.TDFA

type Pattern = String

-- | Given a regular expression and an action, create a `BotComponent` that will
-- execute the action for each encountered substring that matches the pattern.
regex :: Pattern -> (String -> Bot ()) -> Bot Component
regex pattern action = mkComponentT $ regexT pattern actionT
    where
        actionT :: String -> IdentityT Bot ()
        actionT = lift . action

-- | A general regex matching constructor. For each substring in the message
-- that matches will be passed to the action method.
regexT ::  BotMonad b
       =>  Pattern           -- ^ The predicate that determines if the specified action is
                             -- allowed to run.

       ->  (String -> b ())  -- ^ The action to be executed for every substring that matches the regex
       ->  String -> b ()    -- ^ Resulting Botable method
regexT pattern action   =   onPrivMsgT
                        $   mapM_ action
                        .   concat
                        .   match regex
    where
        -- | Generate a regex with specific configurations.
        regex       =   makeRegexOpts compOption execOption pattern
        compOption  =   CompOption {
                        caseSensitive   = True
                    ,   multiline       = True
                    ,   rightAssoc      = True
                    ,   newSyntax       = True
                    ,   lastStarGreedy  = True
                    }
        execOption  =   ExecOption {
                        captureGroups = False
                    }
