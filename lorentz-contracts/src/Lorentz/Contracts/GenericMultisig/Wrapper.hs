
module Lorentz.Contracts.GenericMultisig.Wrapper where

import Data.Singletons
import Data.Constraint hiding (trans)

import Lorentz
import Lorentz.Contracts.ManagedLedger.Types
import Lorentz.Contracts.GenericMultisig
import Lorentz.Contracts.VarStorage
import Lorentz.Contracts.Util ()
import Michelson.Typed.Scope
import Michelson.Typed.Sing
import Michelson.Typed.T
import qualified Lorentz.Contracts.ManagedLedger.Athens as A
import qualified Michelson.TypeCheck.Types as Ty
import qualified Michelson.Typed.Instr as Instr

import Data.Type.Equality
import Data.Typeable
import Prelude (Void, absurd)

-- | Proof that `True` is not `False`
tfToVoid :: 'True :~: 'False -> Void
tfToVoid = \case

-- | A classy witness to the fact that a `T` is equivalent to the case
-- implied by @`ContainsBigMap` t ~ 'True@ and @`BadBigMapPair` t ~ 'False@
class ( t ~ 'TPair ('TBigMap (CBigMapKey t) (CBigMapVal t)) (CWithoutBigMap t)
      , ContainsBigMap (CBigMapVal t) ~ 'False
      , ContainsBigMap (CWithoutBigMap t) ~ 'False
      , Typeable (CBigMapKey t)
      , Typeable (CBigMapVal t)
      , Typeable (CWithoutBigMap t)
      , SingI (CBigMapKey t)
      , SingI (CBigMapVal t)
      , SingI (CWithoutBigMap t)
      ) =>
      ConstrainedBigMap t
  where
  type CBigMapKey (t :: T) :: CT
  type CBigMapVal (t :: T) :: T
  type CWithoutBigMap (t :: T) :: T

-- | `ConstrainedBigMap` has a single instance
instance ( ContainsBigMap v ~ 'False
         , ContainsBigMap t ~ 'False
         , Typeable k
         , Typeable v
         , Typeable t
         , SingI k
         , SingI v
         , SingI t
         ) =>
         ConstrainedBigMap ('TPair ('TBigMap k v) t) where
  type CBigMapKey ('TPair ('TBigMap k v) t) = k
  type CBigMapVal ('TPair ('TBigMap k v) t) = v
  type CWithoutBigMap ('TPair ('TBigMap k v) t) = t

-- | Proof that `ConstrainedBigMap` is implied by
-- @`ContainsBigMap` t ~ 'True@ and @`BadBigMapPair` t ~ 'False@
constrainedBigMapRefl ::
     forall (t :: T).
     Sing (t :: T)
  -> (ContainsBigMap t :~: 'True)
  -> (BadBigMapPair t :~: 'False)
  -> Dict (ConstrainedBigMap t)
constrainedBigMapRefl singT containsBigMap noBadBigMapPair =
  case singT of
    STc _ -> absurd . tfToVoid $ sym containsBigMap
    STKey -> absurd . tfToVoid $ sym containsBigMap
    STSignature -> absurd . tfToVoid $ sym containsBigMap
    STUnit -> absurd . tfToVoid $ sym containsBigMap
    STOption t ->
      case checkBigMapPresence t of
        BigMapPresent -> absurd $ tfToVoid noBadBigMapPair
        BigMapAbsent -> absurd . tfToVoid $ sym containsBigMap
    STList t ->
      case checkBigMapPresence t of
        BigMapPresent -> absurd $ tfToVoid noBadBigMapPair
        BigMapAbsent -> absurd . tfToVoid $ sym containsBigMap
    STSet _ -> absurd . tfToVoid $ sym containsBigMap
    STOperation -> absurd . tfToVoid $ sym containsBigMap
    STContract t ->
      case checkBigMapPresence t of
        BigMapPresent -> absurd $ tfToVoid noBadBigMapPair
        BigMapAbsent -> absurd . tfToVoid $ sym containsBigMap
    STPair a b ->
      case a of
        STBigMap _ v ->
          case checkBigMapPresence v of
            BigMapPresent -> absurd $ tfToVoid noBadBigMapPair
            BigMapAbsent ->
              case checkBigMapPresence b of
                BigMapPresent -> absurd $ tfToVoid noBadBigMapPair
                BigMapAbsent -> Dict
        STc _ -> absurd . tfToVoid $ sym containsBigMap `trans` noBadBigMapPair
        STKey -> absurd . tfToVoid $ sym containsBigMap `trans` noBadBigMapPair
        STSignature ->
          absurd . tfToVoid $ sym containsBigMap `trans` noBadBigMapPair
        STUnit -> absurd . tfToVoid $ sym containsBigMap `trans` noBadBigMapPair
        STOption t ->
          case checkBigMapPresence t of
            BigMapPresent -> absurd $ tfToVoid noBadBigMapPair
            BigMapAbsent ->
              absurd . tfToVoid $ sym containsBigMap `trans` noBadBigMapPair
        STList t ->
          case checkBigMapPresence t of
            BigMapPresent -> absurd $ tfToVoid noBadBigMapPair
            BigMapAbsent ->
              absurd . tfToVoid $ sym containsBigMap `trans` noBadBigMapPair
        STSet _ ->
          absurd . tfToVoid $ sym containsBigMap `trans` noBadBigMapPair
        STOperation ->
          absurd . tfToVoid $ sym containsBigMap `trans` noBadBigMapPair
        STContract t ->
          case checkBigMapPresence t of
            BigMapPresent -> absurd $ tfToVoid noBadBigMapPair
            BigMapAbsent ->
              absurd . tfToVoid $ sym containsBigMap `trans` noBadBigMapPair
        STPair x y ->
          case (checkBigMapPresence x, checkBigMapPresence y) of
            (BigMapPresent, _) -> absurd $ tfToVoid noBadBigMapPair
            (_, BigMapPresent) -> absurd $ tfToVoid noBadBigMapPair
            (BigMapAbsent, BigMapAbsent) ->
              absurd . tfToVoid $ sym containsBigMap `trans` noBadBigMapPair
        STOr x y ->
          case (checkBigMapPresence x, checkBigMapPresence y) of
            (BigMapPresent, _) -> absurd $ tfToVoid noBadBigMapPair
            (_, BigMapPresent) -> absurd $ tfToVoid noBadBigMapPair
            (BigMapAbsent, BigMapAbsent) ->
              absurd . tfToVoid $ sym containsBigMap `trans` noBadBigMapPair
        STLambda _ _ ->
          absurd . tfToVoid $ sym containsBigMap `trans` noBadBigMapPair
        STMap _ v ->
          case checkBigMapPresence v of
            BigMapPresent -> absurd $ tfToVoid noBadBigMapPair
            BigMapAbsent ->
              absurd . tfToVoid $ sym containsBigMap `trans` noBadBigMapPair
    STOr a b ->
      case (checkBigMapPresence a, checkBigMapPresence b) of
        (BigMapPresent, _) -> absurd $ tfToVoid noBadBigMapPair
        (_, BigMapPresent) -> absurd $ tfToVoid noBadBigMapPair
        (BigMapAbsent, BigMapAbsent) -> absurd . tfToVoid $ sym containsBigMap
    STLambda _ _ -> absurd . tfToVoid $ sym containsBigMap
    STMap _ v ->
      case checkBigMapPresence v of
        BigMapPresent -> absurd $ tfToVoid noBadBigMapPair
        BigMapAbsent -> absurd . tfToVoid $ sym containsBigMap
    STBigMap _ _ -> absurd $ tfToVoid noBadBigMapPair

-- | `constrainedBigMapRefl` with the `Refl`'s moved to constraints
constrainedBigMap ::
     forall (t :: T). (ContainsBigMap t ~ 'True, BigMapConstraint t)
  => Sing (t :: T)
  -> Dict (ConstrainedBigMap t)
constrainedBigMap singT =
  constrainedBigMapRefl singT Refl Refl

-- | `explicitlyStorePair` when we know that it `ContainsBigMap` and `BigMapConstraint` holds
explicitlyStorePair' :: forall a b. (SingI (ToT b), ContainsBigMap (ToT b) ~ 'True, BigMapConstraint (ToT b))
  => Contract a b
  -> BigMapContract (CValue (CBigMapKey (ToT b))) (Value (CBigMapVal (ToT b))) a (Value (CWithoutBigMap (ToT b)))
explicitlyStorePair' xs =
  case constrainedBigMap (sing @(ToT b)) of
    Dict -> explicitlyStorePair xs

-- | If `Contract` has a `BigMap`, use the following to make it explicit
-- in storage
explicitlyStorePair :: forall a b c k v. Coercible_ b (BigMap k v, c)
  => Contract a b
  -> BigMapContract k v a c
explicitlyStorePair baseContract = do
  coerce_
  baseContract
  coerce_

-- | If `Contract` does not have a `BigMap`, use the following to
-- add a trivial one.
ignoreBigMap ::
     Contract a b
  -> BigMapContract Bool () a b
ignoreBigMap baseContract = do
  unpair
  swap
  unpair
  dip $ do
    swap
    pair
    baseContract
    unpair
  swap
  dip pair
  pair

-- | Wrap a `Contract` and return
-- @(BigMapContract, specialized multisig contract)@
wrapSomeBigMapContract ::
     forall a b.
     ( KnownValue a
     , NoOperation a
     , NoBigMap a
     , KnownValue b
     , NoOperation b
     , BigMapConstraint (ToT b)
     )
  => Contract a b
  -> (SomeContract, SomeContract)
wrapSomeBigMapContract baseContract =
  case checkBigMapPresence (sing @(ToT b)) of
    BigMapPresent ->
      case constrainedBigMap (sing @(ToT b)) of
        Dict ->
          ( SomeContract $ explicitlyStorePair' baseContract
          , SomeContract $ wrappedMultisigContractProxy
              (Proxy @(CValue (CBigMapKey (ToT b))))
              (Proxy @(Value (CBigMapVal (ToT b))))
              (Proxy @a)
              (Proxy @(Value (CWithoutBigMap (ToT b))))
          )
    BigMapAbsent ->
      ( SomeContract $ ignoreBigMap baseContract
      , SomeContract $ wrappedMultisigContractProxy
              (Proxy @Bool)
              (Proxy @())
              (Proxy @a)
              (Proxy @(Value (ToT b)))
      )

-- | Type-constrained version of `I`
makeI :: Instr.Contract a b -> Contract (Value a) (Value b)
makeI = I

-- | Wrap `SomeContract`, see `wrapSomeBigMapContract`
wrapSomeTypeCheckedContract ::
     Ty.SomeContract
  -> (SomeContract, SomeContract)
wrapSomeTypeCheckedContract (Ty.SomeContract baseContract _ _) =
  wrapSomeBigMapContract $ makeI baseContract


-- | A simple contract to store `Natural`'s
-- @
--  alpha-client originate contract nat_storage for $ALICE_ADDRESS transferring 0 \
--   from $ALICE_ADDRESS running \
--   "parameter nat; storage nat; code {CAR; NIL operation; PAIR};" \
--   --init 0 --burn-cap 0.295
-- @
natStorageContract :: Contract Natural Natural
natStorageContract = varStorageContract

natStorageWithBigMapContract :: BigMapContract Bool () Natural Natural
natStorageWithBigMapContract = ignoreBigMap natStorageContract

wrappedMultisigContractNat ::
     Contract (Parameter Natural) ( BigMap Bool ()
                                  , ( ( BigMapContract Bool () Natural Natural
                                      , Natural)
                                    , Storage))
wrappedMultisigContractNat =
  wrappedMultisigContractProxy
    (Proxy :: Proxy Bool)
    (Proxy :: Proxy ())
    (Proxy :: Proxy Natural)
    (Proxy :: Proxy Natural)

initStorageWrappedMultisigContractNat ::
     Natural
  -> Natural
  -> [PublicKey]
  -> ( BigMap Bool ()
     , ((BigMapContract Bool () Natural Natural, Natural), Storage))
initStorageWrappedMultisigContractNat initialNat threshold keys =
  ( mempty
  , ( (natStorageWithBigMapContract, initialNat)
    , (storedCounter, (threshold, keys))))
  where
    storedCounter = 0

wrappedMultisigContractAthens ::
     Contract (Parameter A.Parameter) ( BigMap Address LedgerValue
                                      , ( ( BigMapContract Address LedgerValue A.Parameter A.StorageFields
                                          , A.StorageFields)
                                        , Storage))
wrappedMultisigContractAthens =
  wrappedMultisigContractProxy
    (Proxy :: Proxy Address)
    (Proxy :: Proxy LedgerValue)
    (Proxy :: Proxy A.Parameter)
    (Proxy :: Proxy A.StorageFields)

initStorageWrappedMultisigContractAthens ::
     Address
  -> Bool
  -> Natural
  -> Either Address Address
  -> Natural
  -> [PublicKey]
  -> ( BigMap Address LedgerValue
     , ( ( BigMapContract Address LedgerValue A.Parameter A.StorageFields
         , A.StorageFields)
       , Storage))
initStorageWrappedMultisigContractAthens admin paused totalSupply proxy threshold keys =
  ( mempty
  , ( (explicitBigMapAthens, A.StorageFields admin paused totalSupply proxy)
    , (0, (threshold, keys))))

explicitBigMapAthens ::
     BigMapContract Address LedgerValue A.Parameter A.StorageFields
explicitBigMapAthens =
  explicitlyStorePair A.managedLedgerAthensContract
