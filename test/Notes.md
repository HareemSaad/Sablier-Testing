## Locks
| File Name | Function | Description | Initial Vesting | Cliff Period | Issuing Months | Balance of multiple streams |
|-----------|----------|-------------|--------------------|------------|----------|---------|
|`LinearLockup_Durations`|`createWithDurations(params)`| waits till cliff period and then linearly unlocks tokens till end time | ❌ | ✅ | ✅ | |


## Functions
| Function | Description |
|----------|-------------|
|`sablierV2LockupLinear.streamedAmountOf(streamId)`| Amounts released |
|`sablierV2LockupLinear.withdrawableAmountOf(streamId)`| Amounts that can be withdrawn at the moment |