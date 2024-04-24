import { expect } from 'chai';
import hre, { ethers } from 'hardhat';
import { time, loadFixture } from '@nomicfoundation/hardhat-toolbox/network-helpers';

import deployVRFContracts from './deploy_vrf';
import { Wheel } from '../typechain-types';

type Bet = { player: string; bettingColor: number; amount: bigint };

describe('Wheel', () => {
    async function deployWheel(generatorAddress: string): Promise<Wheel> {
        return await hre.ethers.deployContract('Wheel', [10, generatorAddress]);
    }

    it('Should create wheel only when it is possible', async () => {
        const [_coordinator, generator] = await loadFixture(deployVRFContracts);
        const wheel = await deployWheel(await generator.getAddress());

        await wheel.createWheel();
        await expect(wheel.createWheel()).to.be.revertedWith('Previous round is not closed');
    });

    it('Should be able to enter the round and add to correct pool', async () => {
        const [_coordinator, generator] = await loadFixture(deployVRFContracts);
        const wheel = await deployWheel(await generator.getAddress());

        await wheel.createWheel();
        await wheel.enterWheel(1, { value: ethers.parseEther('1') });
        const pools = await wheel.getPools(0);

        expect(pools[0]).to.be.equal(ethers.parseEther('1'));
    });

    it('Should send request for number and calculate color when round is opened', async () => {
        const [coordinator, generator] = await loadFixture(deployVRFContracts);
        const wheel = await deployWheel(await generator.getAddress());
        await generator.approve(await wheel.getAddress(), true);
        await wheel.createWheel();

        await expect(wheel.sendRequestForNumber()).to.be.revertedWith('Round is not closed');

        await time.increase(61);

        await wheel.sendRequestForNumber();
        const requestId = await wheel.requestId();

        await coordinator.fulfillRandomWords(requestId, await generator.getAddress());

        expect(await wheel.calculateWinningColor()).to.be.not.equal(0n);
    });

    async function makeABet(
        contract: Wheel,
        signer: any,
        color: number,
        amount: string
    ): Promise<Bet> {
        await contract
            .connect(signer)
            .enterWheel(color, { from: signer.address, value: ethers.parseEther(amount) });

        return { player: signer.address, bettingColor: color, amount: ethers.parseEther(amount) };
    }

    it('Should close the wheel and pay to winners depending on their bets', async () => {
        const [coordinator, generator] = await loadFixture(deployVRFContracts);
        const wheel = await deployWheel(await generator.getAddress());
        await generator.approve(await wheel.getAddress(), true);
        await wheel.createWheel();

        const signers = await ethers.getSigners();

        let black: Bet[] = [];
        black.push(await makeABet(wheel, signers[1], 1, '1'));
        black.push(await makeABet(wheel, signers[2], 1, '2'));
        black.push(await makeABet(wheel, signers[3], 1, '0.5'));

        await makeABet(wheel, signers[4], 2, '1');
        await makeABet(wheel, signers[5], 2, '0.5');
        await makeABet(wheel, signers[6], 3, '3');
        await makeABet(wheel, signers[7], 2, '5');
        await makeABet(wheel, signers[8], 3, '10');
        await makeABet(wheel, signers[9], 3, '0.25');

        await time.increase(61);
        await wheel.sendRequestForNumber();
        const requestId = await wheel.requestId();
        await coordinator.fulfillRandomWords(requestId, await generator.getAddress());

        const balancesBefore = await Promise.all(
            black.map(async (bet: Bet) => await ethers.provider.getBalance(bet.player))
        );

        const winningColor = await wheel.calculateWinningColor();
        await wheel.closeWheel(black, winningColor);

        const balancesAfter = await Promise.all(
            black.map(async (bet: Bet) => await ethers.provider.getBalance(bet.player))
        );

        const totalPool = ethers.parseEther('19.25');
        const prizePool = totalPool - totalPool / 10n;
        const winningPool = ethers.parseEther('3.5');

        const calcPrize = (playerId: number) => {
            const winningAmount =
                (prizePool * black[playerId].amount) / winningPool + black[playerId].amount;
            return parseInt(ethers.formatEther(winningAmount));
        };

        const calcDiff = (playerId: number) => {
            const diff = balancesAfter[playerId] - balancesBefore[playerId];
            return parseInt(ethers.formatEther(diff));
        };

        expect(calcDiff(0)).to.be.equal(calcPrize(0));
        expect(calcDiff(1)).to.be.equal(calcPrize(1));
        expect(calcDiff(2)).to.be.equal(calcPrize(2));
    });
});
