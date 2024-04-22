import { expect } from 'chai';
import hre, { ethers } from 'hardhat';
import { time, loadFixture } from '@nomicfoundation/hardhat-toolbox/network-helpers';

import deployVRFContracts from './deploy_vrf';
import { Jackpot } from '../typechain-types';

type Bet = { player: string; amount: bigint };

describe('Jackpot', () => {
    async function deployJackpot(generatorAddress: string): Promise<Jackpot> {
        return await hre.ethers.deployContract('Jackpot', [10, generatorAddress]);
    }

    async function bet(jackpot: Jackpot, signer: any): Promise<Bet> {
        await jackpot
            .connect(signer)
            .enterJackpot({ from: signer.address, value: ethers.parseEther('1') });

        return {
            player: signer.address,
            amount: ethers.parseEther('1'),
        };
    }

    it('Should create only one round at a time', async () => {
        const [_coordinator, generator] = await loadFixture(deployVRFContracts);
        const jackpot = await deployJackpot(await generator.getAddress());

        await jackpot.createJackpot();
        const round = await jackpot.rounds(0);

        await expect(jackpot.createJackpot()).to.be.revertedWith('Previous round is still going');
        expect(round.timestamp).to.be.not.equal(0);
    });

    it('Should enter the round only when it is opened', async () => {
        const [_coordinator, generator] = await loadFixture(deployVRFContracts);
        const jackpot = await deployJackpot(await generator.getAddress());
        await jackpot.createJackpot();

        const signers = await ethers.getSigners();
        await bet(jackpot, signers[1]);
        await bet(jackpot, signers[1]);

        const round = await jackpot.rounds(0);
        expect(round.pool).to.be.equal(ethers.parseEther('2'));

        await time.increase(61);
        await expect(bet(jackpot, signers[1])).to.be.revertedWith('Round is closed');
    });

    it('Should send a request for number only when the round is open', async () => {
        const [_coordinator, generator] = await loadFixture(deployVRFContracts);
        const jackpot = await deployJackpot(await generator.getAddress());

        await generator.approve(await jackpot.getAddress(), true);
        await jackpot.createJackpot();

        await expect(jackpot.sendRequestForNumber()).to.be.revertedWith('Round is not closed');

        await time.increase(61);

        await jackpot.sendRequestForNumber();

        expect(await jackpot.requestId()).to.be.not.equal(0n);
    });

    it('Should close the round only when number is ready', async () => {
        const [coordinator, generator] = await loadFixture(deployVRFContracts);
        const jackpot = await deployJackpot(await generator.getAddress());

        await generator.approve(await jackpot.getAddress(), true);
        await jackpot.createJackpot();

        await time.increase(61);

        await jackpot.sendRequestForNumber();

        await expect(jackpot.closeJackpot([])).to.be.revertedWith('The request was not fulfilled');

        const requestId = await jackpot.requestId();

        await coordinator.fulfillRandomWords(requestId, await generator.getAddress());

        await jackpot.closeJackpot([]);
    });

    it('Should pay to the winner and save comission after round is closed', async () => {
        const [coordinator, generator] = await loadFixture(deployVRFContracts);
        const jackpot = await deployJackpot(await generator.getAddress());

        await generator.approve(await jackpot.getAddress(), true);
        await jackpot.createJackpot();

        const signers = await ethers.getSigners();

        let bets: Bet[] = [];
        bets.push(await bet(jackpot, signers[1]));
        bets.push(await bet(jackpot, signers[2]));
        bets.push(await bet(jackpot, signers[3]));
        bets.push(await bet(jackpot, signers[1]));

        await time.increase(61);

        await jackpot.sendRequestForNumber();
        const requestId = await jackpot.requestId();
        await coordinator.fulfillRandomWords(requestId, await generator.getAddress());

        let balancesBefore: bigint[] = [];
        bets.forEach(async (bet) => {
            balancesBefore.push(await ethers.provider.getBalance(bet.player));
        });

        await jackpot.closeJackpot(bets);

        const [winner, pool, _timestamp] = await jackpot.rounds(0);

        const contractBalance = await ethers.provider.getBalance(await jackpot.getAddress());
        expect(contractBalance).to.be.equal(pool / 10n);

        const winnerIdInBalances =
            winner == signers[1].address ? 0 : winner == signers[2].address ? 1 : 2;
        const winnerBefore = balancesBefore[winnerIdInBalances];
        const winnerAfter = await ethers.provider.getBalance(winner);

        expect(winnerAfter - winnerBefore).to.be.equal(pool - pool / 10n);
    });
});
