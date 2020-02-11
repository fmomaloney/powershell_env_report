# powershell_env_report
example of powershell script that reports code present in QA environments

In recent employment, we had a lot of QA environments with hosts that were on various code builds. It was hard to find that status without digging through config files, so I wrote a script to read from the XML config and write a simple report. Since these were all windows environments, I used powershell to get the info. I put the script on windows task scheduler and ran it daily. This report was helpful to QA and product. 

See the CSV report for example output. 
