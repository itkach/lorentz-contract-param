-- | 'TxData' type and associated functionality.

module Morley.Runtime.TxData
       ( TxData (..)
       ) where

import Michelson.Types
import Tezos.Crypto (Address)

-- | Data associated with a particular transaction.
data TxData = TxData
  { tdSenderAddress :: !Address
  , tdParameter :: !(Value Op)
  , tdAmount :: !Mutez
  } deriving (Show)
