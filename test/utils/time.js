const { ethers } = require("hardhat");

const { BigNumber } = ethers;

const TimeHelper = {
    advanceBlock: async () => {
        return ethers.provider.send("evm_mine", []);
    },
    advanceBlockTo: async (blockNumber) => {
        for (let i = await ethers.provider.getBlockNumber(); i < blockNumber; i++) {
            await advanceBlock();
        }
    },
    increase: async (value) => {
        await ethers.provider.send("evm_increaseTime", [value.toNumber()]);
        await this.advanceBlock();
    },
    latestBlockTimestamp: async () => {
        const block = await ethers.provider.getBlock("latest");
        return BigNumber.from(block.timestamp);
    },
    latestBlockNumber: async () => {
        const block = await ethers.provider.getBlock("latest");
        return BigNumber.from(block.number);
    },
    advanceTimeAndBlock: async (time) => {
        await TimeHelper.advanceTime(time);
        await TimeHelper.advanceBlock();
    },
    advanceTime: async (time) => {
        await ethers.provider.send("evm_increaseTime", [time]);
    },
    duration: {
        seconds: (val) => {
            return BigNumber.from(val)
        },
        minutes: (val) => {
            return BigNumber.from(val).mul(this.seconds("60"))
        },
        hours: (val) => {
            return BigNumber.from(val).mul(this.minutes("60"))
        },
        days: (val) => {
            return BigNumber.from(val).mul(this.hours("24"))
        },
        weeks: (val) => {
            return BigNumber.from(val).mul(this.days("7"))
        },
        years: (val) => {
            return BigNumber.from(val).mul(this.days("365"))
        },
    }
}

module.exports = TimeHelper;