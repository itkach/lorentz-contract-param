module Lorentz.Test
  ( -- * Importing a contract
    specWithContract
  , specWithTypedContract
  , specWithUntypedContract

  -- * Unit testing
  , ContractReturn
  , ContractPropValidator
  , contractProp
  , contractPropVal
  , contractRepeatedProp
  , contractRepeatedPropVal

  -- * Integrational testing
  -- ** Testing engine
  , IntegrationalValidator
  , SuccessValidator
  , IntegrationalScenario
  , IntegrationalScenarioM
  , ValidationError (..)
  , integrationalTestExpectation
  , integrationalTestProperty
  , lOriginate
  , lOriginateEmpty
  , lTransfer
  , lCall
  , uCall
  , validate
  , setMaxSteps
  , setNow
  , withSender
  , branchout
  , (?-)

  -- ** Validators
  , composeValidators
  , composeValidatorsList
  , expectAnySuccess
  , lExpectStorageUpdate
  , lExpectBalance
  , lExpectStorageConst
  , lExpectMichelsonFailed
  , lExpectFailWith
  , lExpectError
  , lExpectConsumerStorage
  , lExpectViewConsumerStorage

  -- ** Various
  , TxData (..)
  , genesisAddresses
  , genesisAddress
  , genesisAddress1
  , genesisAddress2
  , genesisAddress3
  , genesisAddress4
  , genesisAddress5
  , genesisAddress6

  -- * General utilities
  , failedProp
  , succeededProp
  , qcIsLeft
  , qcIsRight

  -- * Dummy values
  , dummyContractEnv

  -- * Arbitrary data
  , minTimestamp
  , maxTimestamp
  , midTimestamp
  ) where

import Michelson.Test.Dummy
import Michelson.Test.Gen
import Michelson.Test.Import
import Michelson.Test.Unit
import Michelson.Test.Util

import Lorentz.Test.Integrational as Exports
